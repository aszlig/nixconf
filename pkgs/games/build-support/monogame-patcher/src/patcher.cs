using System.Collections.Generic;
using System.IO;
using System.Linq;
using System;

using Mono.Cecil.Cil;
using Mono.Cecil.Rocks;
using Mono.Cecil;

using CommandLine;

class Command {
    protected string infile;
    protected string outfile;
    protected ModuleDefinition module;

    public Command(GenericOptions options) {
        if (options.outputFile == null)
            this.outfile = options.inputFile;
        else
            this.outfile = options.outputFile;
        this.infile = options.inputFile;

        var readOnly = this.infile != this.outfile;
        this.module = this.read_module(this.infile, readOnly);
    }

    protected ModuleDefinition read_module(string path, bool readOnly) {
        var resolver = new DefaultAssemblyResolver();
        resolver.AddSearchDirectory(Path.GetDirectoryName(path));

        var rp = new ReaderParameters {
            ReadWrite = !readOnly,
            AssemblyResolver = resolver
        };
        return ModuleDefinition.ReadModule(path, rp);
    }

    protected virtual IEnumerable<TypeDefinition> get_assembly_types() {
        return this.module.AssemblyReferences
            .Select(a => this.module.AssemblyResolver.Resolve(a))
            .SelectMany(r => r.MainModule.Types);
    }

    protected MethodReference find_method_ref(string fullSig) {
        foreach (var type in this.get_assembly_types()) {
            foreach (var ctor in type.GetConstructors()) {
                if (ctor.ToString() != fullSig) continue;
                return this.module.ImportReference(ctor);
            }
            foreach (var meth in type.GetMethods()) {
                if (meth.ToString() != fullSig) continue;
                return this.module.ImportReference(meth);
            }
        }

        throw new Exception($"Method reference for {fullSig} not found.");
    }

    public void save() {
        if (this.outfile == this.infile)
            this.module.Write();
        else
            this.module.Write(this.outfile);
    }
}

class FixFileStreams : Command {
    private MethodReference betterFileStream;

    public FixFileStreams(FixFileStreamsCmd options) : base(options) {
        var filtered = this.module.Types
            .Where(p => options.typesToPatch.Contains(p.Name));

        this.betterFileStream = this.find_method_ref(
            "System.Void System.IO.FileStream::.ctor" +
            "(System.String,System.IO.FileMode,System.IO.FileAccess)"
        );

        foreach (var toPatch in filtered)
            patch_type(toPatch);

        this.save();
    }

    private void patch_method(MethodDefinition md) {
        var il = md.Body.GetILProcessor();

        var fileStreams = md.Body.Instructions
            .Where(i => i.OpCode == OpCodes.Newobj)
            .Where(i => (i.Operand as MethodReference).DeclaringType
                    .FullName == "System.IO.FileStream");

        foreach (Instruction i in fileStreams.ToList()) {
            var fileAccessRead = il.Create(OpCodes.Ldc_I4_1);
            il.InsertBefore(i, fileAccessRead);
            il.Replace(i, il.Create(OpCodes.Newobj, this.betterFileStream));
        }
    }

    private void patch_type(TypeDefinition td) {
        foreach (var nested in td.NestedTypes) patch_type(nested);
        foreach (MethodDefinition md in td.Methods) patch_method(md);
    }
}

class ReplaceCall : Command {
    private string search;
    private MethodReference replace;
    private ModuleDefinition targetModule;
    private bool patch_done;

    public ReplaceCall(ReplaceCallCmd options) : base(options) {
        if (options.assemblyFile != null)
            this.targetModule = this.read_module(options.assemblyFile, true);

        this.search = options.replaceMethod;
        this.replace = this.find_method_ref(options.replacementMethod);

        var filtered = this.module.Types
            .Where(p => options.typesToPatch.Contains(p.Name));

        this.patch_done = false;
        foreach (var toPatch in filtered)
            patch_type(toPatch);

        if (!this.patch_done) {
            var types = string.Join(", ", options.typesToPatch);
            throw new Exception($"Unable to find {this.search} in {types}.");
        }

        this.save();
    }

    protected override IEnumerable<TypeDefinition> get_assembly_types() {
        if (this.targetModule != null)
            return this.targetModule.Types;
        else
            return base.get_assembly_types();
    }

    private void patch_method(MethodDefinition md) {
        var il = md.Body.GetILProcessor();

        var found = md.Body.Instructions
            .Where(i => i.OpCode == OpCodes.Call)
            .Where(i => i.Operand.ToString() == this.search);

        foreach (Instruction i in found.ToList()) {
            il.Replace(i, il.Create(OpCodes.Call, this.replace));
            this.patch_done = true;
        }
    }

    private void patch_type(TypeDefinition td) {
        foreach (var nested in td.NestedTypes) patch_type(nested);
        foreach (MethodDefinition md in td.Methods) patch_method(md);
    }
}

public class patcher {
    public static int Main(string[] args) {
        var parser = new Parser((settings) => {
            settings.EnableDashDash = true;
            settings.HelpWriter = Console.Error;

            // XXX: When not running in a terminal the width is 0, but the
            //      CommandLine library expects it to be greater than zero.
            if (Console.WindowWidth == 0)
                settings.MaximumDisplayWidth = 80;
        });

        parser.ParseArguments<FixFileStreamsCmd, ReplaceCallCmd>(args)
            .WithParsed<FixFileStreamsCmd>(opts => new FixFileStreams(opts))
            .WithParsed<ReplaceCallCmd>(opts => new ReplaceCall(opts));
        return 0;
    }
}
