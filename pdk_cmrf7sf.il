;; pdk_cmrf7sf.il -- everything specific to the IBM 7RF (cmrf7sf) PDK on UCSD ieng6.
;; Every circuit script reads its PDK details from acPdk, so switching PDKs
;; means writing one new file like this and loading it instead.

acPdk = list(nil
  'name       "cmrf7sf"
  'lib        "cmrf7sf"      ; library holding the devices
  'nmos       "nfet"         ; terminals D G S, substrate via global net sub!
  'pmos       "pfet"         ; not yet verified
  'nmosW      "w"            ; CDF name of the width  -- not yet verified, check with acDumpParams
  'nmosL      "l"            ; CDF name of the length -- not yet verified
  'subNet     "sub!"         ; global substrate net created by the PDK; tied to gnd
  'modelPath  "/acsnfs3/software/IBM7RF/IBM_PDK/cmrf7sf/V2.0.0.2AM/Spectre/models"
  ;; (file section) -- a section of "" means no section; "tt" is replaced by the chosen corner
  'modelFiles '(("design.scs" "") ("wafer.scs" "") ("allModels.scs" "tt"))
  ;; design variables the PDK adds to every cell
  'desVars    '(("p5vonly" 0) ("phires" 0))
  'temp       27
)

printf("PDK config loaded: %s\n" acPdk->name)
