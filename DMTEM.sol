// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title D-MTEM: Dynamic Multidimensional Trust Evaluation Model
 * @notice On-chain aggregation step of D-MTEM. Four channel scores (identity,
 *         behavior, relation, feedback) are combined by rank-position ordered
 *         weighted averaging (OWA):
 *
 *             T = w1*s(1) + w2*s(2) + w3*s(3) + w4*s(4)          (Equation 1)
 *
 *         where s(k) is the score of the channel holding stability rank k and
 *         w = (0.500, 0.207, 0.159, 0.134), so that w1 + w2 + w3 + w4 = 1.
 *
 * @dev Properties stated in the manuscript, for scores in [0, 1]:
 *      - Proposition 1: one channel changing its score and rank moves T by
 *        at most w1 = 0.500.
 *      - Proposition 2: re-ordering the ranks of fixed scores moves T by at
 *        most (w1 + w2) - (w3 + w4) = 0.414.
 *      These bounds cover the aggregation step only.
 *
 *      Scope of this contract:
 *      - The stability ranking (EIMD criterion) is not computed here. The
 *        caller supplies it, and the contract only checks that it is a valid
 *        permutation of the four channels.
 *      - Rank indices run from 0 (most stable, manuscript rank 1) to 3
 *        (least stable, manuscript rank 4).
 *      - updateTrust has no access control: any account can write the score of
 *        any node. Restrict the caller (for example to an oracle or registry
 *        contract) before using this outside a test network.
 *
 *      Scores and weights are fixed-point numbers with 18 decimals (1e18 = 1.0).
 */
contract DMTEM {
    uint256 private constant SCALE = 1e18;

    // Position weights, scaled by 1e18.
    uint256 private constant W1 = 0.500 ether;
    uint256 private constant W2 = 0.207 ether;
    uint256 private constant W3 = 0.159 ether;
    uint256 private constant W4 = 0.134 ether;

    struct TrustNode {
        uint256 identityScore;  // channel scores and aggregate lie in [0, 1e18]
        uint256 behaviorScore;
        uint256 relationScore;
        uint256 feedbackScore;
        uint256 aggregateTrust;
        uint256 lastUpdate;     // block timestamp of the latest update
    }

    mapping(address => TrustNode) public trustRegistry;

    event TrustUpdated(
        address indexed node,
        uint256 aggregateTrust,
        uint256 timestamp
    );

    constructor() {
        require(W1 + W2 + W3 + W4 == SCALE, "Weights must sum to 1");
    }

    /**
     * @notice Store the four channel scores of a node and its aggregate trust.
     * @param node            Address of the evaluated entity.
     * @param sId             Identity channel score, scaled by 1e18.
     * @param sBe             Behavior channel score, scaled by 1e18.
     * @param sRe             Relation channel score, scaled by 1e18.
     * @param sFe             Feedback channel score, scaled by 1e18.
     * @param stabilityRanks  Stability rank of each channel, in the order
     *                        [identity, behavior, relation, feedback]. Must be
     *                        a permutation of 0..3 (0 = most stable).
     */
    function updateTrust(
        address node,
        uint256 sId,
        uint256 sBe,
        uint256 sRe,
        uint256 sFe,
        uint8[4] calldata stabilityRanks
    ) external {
        require(
            sId <= SCALE && sBe <= SCALE && sRe <= SCALE && sFe <= SCALE,
            "Scores out of bounds"
        );
        require(isValidPermutation(stabilityRanks), "Invalid rank permutation");

        uint256[4] memory scores = [sId, sBe, sRe, sFe];
        uint256[4] memory byRank; // byRank[k] = score of the channel at rank k

        for (uint8 i = 0; i < 4; i++) {
            byRank[stabilityRanks[i]] = scores[i];
        }

        // Equation 1. The largest intermediate value is about 1e36, far below 2^256.
        uint256 aggregate = (W1 * byRank[0] +
                             W2 * byRank[1] +
                             W3 * byRank[2] +
                             W4 * byRank[3]) / SCALE;

        trustRegistry[node] = TrustNode({
            identityScore: sId,
            behaviorScore: sBe,
            relationScore: sRe,
            feedbackScore: sFe,
            aggregateTrust: aggregate,
            lastUpdate: block.timestamp
        });

        emit TrustUpdated(node, aggregate, block.timestamp);
    }

    /// @notice Aggregate trust of a node, scaled by 1e18 (0 if never updated).
    function getTrust(address node) external view returns (uint256) {
        return trustRegistry[node].aggregateTrust;
    }

    function isValidPermutation(uint8[4] memory ranks) private pure returns (bool) {
        bool[4] memory seen;
        for (uint8 i = 0; i < 4; i++) {
            if (ranks[i] > 3 || seen[ranks[i]]) return false;
            seen[ranks[i]] = true;
        }
        return true;
    }
}
