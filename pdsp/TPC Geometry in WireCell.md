```json
// pgrapher/experiment/pdsp/simparams.jsonnet

// local apa_cpa = 3.637*wc.m, // Doc-203
local apa_cpa = 3.63075*wc.m, // LArSoft
local apa_plane = 0.5*apa_g2g - plane_gap, // pick it to be at the first induction wiresp
```

Here, CPA center is 0, `apa_cpa` indicates the distance between the APA center and the CPA center.

In the LAr (87K), the TPC frame shinks by about 6mm (source: Flavio). So the LArSoft value is better. Try `lar -c dump_protodunesp_geometry.fcl` and find some wire positions, e.g., C:0 T:0 P:0.

