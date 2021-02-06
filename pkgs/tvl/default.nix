{ tvlSrc ? builtins.fetchGit {
    name = "tvl-depot";
    url = "https://code.tvl.fyi";
    rev = "9b973c201120d7168611134f4aa4d6536f9ccd38";
    ref = "canon";
  }
}:

import tvlSrc { }
