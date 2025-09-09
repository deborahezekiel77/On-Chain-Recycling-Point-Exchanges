# ♻️ On-Chain Recycling Point Exchange

A Clarity smart contract that tracks recyclable material contributions and rewards users with tradeable tokens redeemable for eco-friendly goods.

## 🌟 Features

- **Material Tracking**: Record different types of recyclable materials
- **Point System**: Earn Recycling Points (RCP) tokens for contributions
- **Reward Catalog**: Redeem points for eco-friendly products
- **Transfer System**: Trade points between users
- **Leaderboard**: Track top contributors
- **Batch Operations**: Submit multiple contributions at once

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation
```bash
git clone <repository-url>
cd On-Chain-Recycling-Point-Exchange
clarinet check
```

## 📋 Usage

### For Contributors

#### Contribute Materials
```clarity
(contract-call? .On-Chain-Recycling-Point-Exchange contribute-material u1 u5)
```
- `u1`: Material type ID (1=Plastic Bottles, 2=Glass Bottles, 3=Aluminum Cans, 4=Paper Waste)
- `u5`: Quantity contributed

#### Check Your Balance
```clarity
(contract-call? .On-Chain-Recycling-Point-Exchange get-user-balance tx-sender)
```

#### Redeem Rewards
```clarity
(contract-call? .On-Chain-Recycling-Point-Exchange redeem-reward u1)
```
- `u1`: Reward ID from catalog

#### Transfer Points
```clarity
(contract-call? .On-Chain-Recycling-Point-Exchange transfer-points u50 'SP1234...)
```

### For Administrators

#### Add Material Types
```clarity
(contract-call? .On-Chain-Recycling-Point-Exchange add-material-type "Cardboard" u8)
```

#### Add Rewards
```clarity
(contract-call? .On-Chain-Recycling-Point-Exchange add-reward "Eco Mug" u200 u15)
```

## 🏆 Default Setup

### Material Types
- 🍼 **Plastic Bottles**: 10 points per unit
- 🍷 **Glass Bottles**: 15 points per unit  
- 🥤 **Aluminum Cans**: 20 points per unit
- 📄 **Paper Waste**: 5 points per unit

### Reward Catalog
- 💧 **Eco-Friendly Water Bottle**: 100 points
- 🛍️ **Reusable Shopping Bag**: 150 points
- 🔋 **Solar Power Bank**: 500 points
- 🥢 **Bamboo Cutlery Set**: 75 points

## 🔍 Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-user-balance` | Get user's RCP token balance |
| `get-user-contributions` | Get total materials contributed by user |
| `get-material-type` | Get material type info by ID |
| `get-reward-info` | Get reward details by ID |
| `get-total-contributions` | Get platform-wide contribution stats |
| `get-contract-stats` | Get comprehensive contract statistics |

## 📊 Testing

Run the test suite:
```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🌱 Environmental Impact

This contract promotes recycling by:
- Incentivizing proper waste disposal
- Rewarding sustainable behavior
- Creating a circular economy for recyclable materials
- Encouraging community participation in environmental conservation

---

*Made with 💚 for a sustainable future*
