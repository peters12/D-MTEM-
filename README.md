[README.txt](https://github.com/user-attachments/files/34687805/README.txt)
D-MTEM: Dynamic Multidimensional Trust Evaluation Model
Code and data repository


ABOUT

This repository accompanies the manuscript

  Obiria, P., & Nderu, L. (2026). Bounding single-channel influence in
  multidimensional trust aggregation for blockchain-based reputation systems:
  stability-ordered position weighting, analytical bounds, and evaluation under
  collusion attacks. PeerJ Computer Science.

D-MTEM scores a node from four evidence channels: identity, behavior, relation
and feedback. The channels are ranked by their moving-dispersion stability (the
Entropy-Invariant Moving Dispersion, EIMD, criterion), and the ranked scores are
combined by position-based ordered weighted averaging (OWA). Because the weights
belong to rank positions and not to the entropy or variance a channel reports, a
low-variance collusive channel cannot raise its own weight.

The guarantees cover the aggregation step only. D-MTEM does not detect a
colluding channel, and its error rises when all four channels are attacked
synchronously on a large share of nodes (see Limitations).


CONTENTS

  DMTEM_Dataset.csv         Labelled evaluation set (10,000 interactions)
  data_codebook.txt         Field definitions and labelling rules for the dataset
  DMTEM.sol                 Solidity implementation of the aggregation step
  dmtem_simulation.py       Python implementation of D-MTEM and the five comparison models
  synthetic_attack_sims.csv Results of the synthetic benchmark runs


DATASET

DMTEM_Dataset.csv is a file of 10,000 timestamped interactions among
1,000 nodes, on the rating scale of the Stanford SNAP Bitcoin OTC web-of-trust
network (5,881 nodes, 35,592 ratings; Kumar et al., 2016;
https://snap.stanford.edu/data/soc-sign-bitcoinotc.html).

Columns:

  Timestamp_ms, Source_Node_ID, Target_Node_ID, Observed_Latency_ms,
  Transaction_Success, Feedback_Rating_OTC, Malicious_Actor_GroundTruth,
  Detected_Attack_Pattern, MTEM_Dynamic_Trust_Weight

Labels (Malicious_Actor_GroundTruth):

  1 = malicious      2,965 rows (29.65%): 1,814 bad-mouthing and 1,151 ballot-stuffing
  0 = non-malicious  7,035 rows (70.35%): 6,754 honest and 281 ambiguous

The 281 ambiguous interactions carry no attack pattern, have ratings between -5
and +1, and all had failed transactions. They were labelled non-malicious because
a failed transaction can reflect a network fault and is not by itself evidence of
malice. Raw ratings R in [-10, +10] are normalized as T_norm = (R + 10) / 20.
Full definitions, value ranges and the labelling rules are in data_codebook.txt.

The Bitcoin OTC labels are derived from the rating stream the models consume, so
results on this file measure agreement with rating-derived labels, not verified
honesty.


BENCHMARK

Networks of 10,000 nodes are simulated over 200 time steps. The share of
malicious nodes runs from 10% to 80% in eight steps, with three attack scenarios
(bad-mouthing, ballot-stuffing, combined Sybil) and ten random seeds, giving 240
runs. Honest ratings are drawn from N(0.85, 0.05) and collusive ratings from
N(0.98, 0.005). Each run is scored with six models (D-MTEM, MarketTrust,
Info-Trust, MFTC, RLTS and an equal-weight static baseline), giving 1,440 model
evaluations. Single-channel and synchronous multi-channel low-variance collusion
are evaluated as separate attack modes. The ablation variants reported in the
manuscript are run separately.


METHOD SUMMARY

For channel scores s in [0, 1], with s(k) the score of the channel at stability
rank k, the aggregate trust is

  T = 0.500*s(1) + 0.207*s(2) + 0.159*s(3) + 0.134*s(4)

Bounds proved in the manuscript (scores in [0, 1], aggregation step only):

  - A single channel that changes both its score and its rank moves T by at
    most 0.500 (Proposition 1).
  - Re-ordering the ranks of fixed scores moves T by at most 0.414 (Proposition 2).


SMART CONTRACT (DMTEM.sol)

Solidity 0.8.20, MIT licence. Scores and weights are fixed-point numbers with
18 decimals (1e18 = 1.0), and the four position weights are contract constants.

  updateTrust(node, sId, sBe, sRe, sFe, stabilityRanks)
      stores the four channel scores and the aggregate T for a node and emits
      TrustUpdated. stabilityRanks gives the rank of each channel in the order
      [identity, behavior, relation, feedback] and must be a permutation of 0..3,
      where 0 is the most stable channel (rank 1 in the manuscript).
  getTrust(node)
      returns the stored aggregate, scaled by 1e18.

Points to note:

  - The EIMD ranking is not computed on-chain; the caller supplies it.
  - updateTrust has no access control. Restrict the caller before deploying
    anywhere other than a test network.
  - Deployment targets in the manuscript: the Sepolia proof-of-stake test
    network and a Polygon Edge proof-of-authority network.
  - The manuscript reports 42,500 gas per state update and a confirmation latency
    of about 1.2 s on Polygon Edge. Gas depends on the storage layout and on
    whether the node's slots already hold values, so measure it for the exact
    contract you deploy (for example with hardhat-gas-reporter).

Compile and test:

  npx hardhat compile
  npx hardhat test


SIMULATION CODE (dmtem_simulation.py)

Requirements: Python 3.9 or later; numpy 1.21 or later, pandas 1.3 or later,
scikit-learn 1.0 or later, scipy 1.7 or later.

  pip install numpy pandas scikit-learn scipy
  python dmtem_simulation.py --dataset DMTEM_Dataset.csv --runs 50

The Bitcoin OTC evaluation is a Monte Carlo experiment with N = 50 runs and
reports MAE, precision, recall, F1-score, false-negative rate and convergence
steps for all six models. Where a value is written as mean +/- s, s is the sample
standard deviation (n - 1) across runs. Table 1 of the manuscript gives the
reference result for D-MTEM: MAE 0.0855, precision 0.9100, recall 0.8906,
F1-score 0.9002, convergence in 17.1 steps.

The contract needs Node.js 16 or later and Hardhat or Foundry, with solc ^0.8.20.


LIMITATIONS

  - Rank-position weighting bounds the influence of one channel, not of all four.
    With synchronous collusion across all channels on more than 60% of nodes, the
    MAE of D-MTEM rose from 0.0682 (single-dimension collusion) to 0.1840.
  - The authors chose the synthetic rating distributions, and adaptive
    attackers that respond to the ranking rule were not tested.
  - The bounds say nothing about how accurately the channel scores themselves are
    estimated.
  - Graph-based trust models such as TrustGuard were not compared.
  - Gas and latency figures come from test and private-network deployments.


CITATION

Obiria, P., & Nderu, L. (2026). Bounding single-channel influence in
multidimensional trust aggregation for blockchain-based reputation systems:
stability-ordered position weighting, analytical bounds, and evaluation under
collusion attacks. PeerJ Computer Science.


LICENCE AND CONTACT

MIT License. 

