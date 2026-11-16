;; ece203_ss_chop.il -- ECE203 Round 3D: 1 MHz ideal-clock / ideal-switch chopper around the single-stage S2 BioAmp.
;; Work order: docs/ECE203_round3d_ideal_chopper_ceiling_microtest.md.

;; probe analogLib pieces used here (symbol pins + CDF parameter names/defaults)
procedure( chProbe()
  foreach(c '("switch" "vpulse" "vcvs" "relay")
    let( (m cdf)
      m = dbOpenCellViewByType("analogLib" c "symbol")
      if( m then
        foreach(tm m~>terminals
          acSay("chp: analogLib/%s pin %s at %L\n" c tm~>name mapcar(lambda((p) centerBox(p~>fig~>bBox)) tm~>pins)))
      else acSay("chp: no analogLib/%s symbol\n" c))
      cdf = car(errset(cdfGetBaseCellCDF(ddGetObj("analogLib" c)) nil))
      when( cdf
        foreach(p cdf~>parameters
          acSay("chp: analogLib/%s CDF %s (%s) default %L\n" c p~>name p~>prompt p~>defValue)))))
  t
)
