library(BoolNet)

network <- loadNetwork("~/PycharmProjects/scrap/booleanTestNetwork.txt")


fixGenes( network, "p53", 0)


fixGenes( network, "TGFbeta", 1)

fixGenes( network, "SNAI2", 1)


fixGenes( network, "AKT1", 1)

attr <- getAttractors(network, method = "chosen", startStates = list(c(0,
0,
0,
0,
1,
1,
1,
0,
1,
1,
0,
1,
0,
1,
1,
0,
1,
1,
1,
1,
0,
1,
1,
0,
0, 0, 1,
0,
1,
0, 1, 1)))

attrSeq <- getAttractorSequence(attr, 1)

if (all(attrSeq[ , 26] == 1)){
  print(0)
} else {
  print(1)
}