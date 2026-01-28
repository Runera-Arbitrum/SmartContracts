# 🏃 RUNERA - 3-Layer Identity NFT Protocol

> **Decentralized Profile, Achievement & Cosmetic System with Dynamic Soulbound NFTs**

[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange)](https://getfoundry.sh/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.4.0-purple)](https://openzeppelin.com/contracts/)
[![Tests](https://img.shields.io/badge/Tests-112%20Passed-green)]()
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

---

## 📋 Table of Contents

- [Overview](#-overview)
- [3-Layer Architecture](#-3-layer-architecture)
- [Smart Contracts](#-smart-contracts)
- [Features](#-features)
- [Security](#-security)
- [Getting Started](#-getting-started)
- [Deployment](#-deployment)
- [Testing](#-testing)
- [License](#-license)

---

## 🎯 Overview

**RUNERA** is a 3-layer decentralized identity protocol built on EVM chains. It combines on-chain data storage with dynamic NFT visualization for profiles, achievements, and cosmetic items.

### Core Concept

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: IDENTITY (Profile Soulbound NFT)                  │
│  └─ On-chain stats + Dynamic tier-based NFT metadata        │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: PROOF (Achievement Soulbound NFT)                 │
│  └─ Event-based achievements + Non-transferable NFTs        │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: ECONOMY (Cosmetic Transferable NFT + Marketplace) │
│  └─ Tradeable items + Equip/unequip mechanics               │
└─────────────────────────────────────────────────────────────┘
```

### Why RUNERA?

| Feature | Description |
|---------|-------------|
| 🎨 **Dynamic NFTs** | Profile tier upgrades automatically reflect in NFT metadata |
| 🔒 **Soulbound** | Profile & Achievement NFTs cannot be transferred |
| 💎 **Tradeable Cosmetics** | Cosmetic items can be traded on marketplace |
| ⛽ **Gas Optimized** | Packed structs, cached roles, minimal storage |
| 🔐 **Secure** | EIP-712 signatures, nonce replay protection |

---

## 🏗️ 3-Layer Architecture

### Layer 1: Identity (Profile Dynamic NFT)

```solidity
// One soulbound NFT per wallet
// Token ID = uint256(uint160(address))
// Tier automatically upgrades based on level

Bronze (Lv 1-2) → Silver (Lv 3+) → Gold (Lv 5+) → Platinum (Lv 7+) → Diamond (Lv 9+)
```

**On-chain data:**
- XP, Level, Tasks Completed, Achievement Count
- Dynamic metadata URI based on tier

### Layer 2: Proof (Achievement Dynamic NFT)

```solidity
// One soulbound NFT per user per event
// Token ID = keccak256(address, eventId)
// Claimed via backend signature

Tier 1-5 ranking system with metadata hash storage
```

### Layer 3: Economy (Cosmetic NFT + Marketplace)

```solidity
// TRANSFERABLE items (unlike Profile/Achievement)
// Categories: Shoes, Outfit, Accessory, Frame
// Rarity: Common → Uncommon → Rare → Epic → Legendary → Mythic

// Marketplace features:
// - List items for sale (escrow)
// - Buy with ETH
// - Platform fee (5%)
```

---

## 📁 Smart Contracts

| Contract | Type | Purpose |
|----------|------|---------|
| `RuneraAccessControl.sol` | Access Control | Centralized role management |
| `RuneraProfileDynamicNFT.sol` | ERC-1155 Soulbound | Profile with dynamic metadata |
| `RuneraAchievementDynamicNFT.sol` | ERC-1155 Soulbound | Event-based achievements |
| `RuneraEventRegistry.sol` | Registry | Event lifecycle management |
| `RuneraCosmeticNFT.sol` | ERC-1155 Transferable | Tradeable cosmetic items |
| `RuneraMarketplace.sol` | Marketplace | Buy/sell cosmetic items |

---

## 🚀 Features

### Profile System
- ✅ One soulbound NFT per wallet
- ✅ On-chain data storage (XP, level, stats)
- ✅ Dynamic tier system (Bronze → Diamond)
- ✅ Backend-authorized stats updates via EIP-712 signatures

### Achievement System
- ✅ Soulbound achievement NFTs
- ✅ Event-based claiming with signature verification
- ✅ 5-tier ranking system
- ✅ User achievement enumeration

### Event Registry
- ✅ Time-window based activation
- ✅ Participant capacity management
- ✅ Event Manager role restrictions

### Cosmetic System
- ✅ Transferable ERC-1155 items
- ✅ Category system (4 slots)
- ✅ Rarity system (6 levels)
- ✅ Equip/unequip mechanics
- ✅ Supply management

### Marketplace
- ✅ List items with escrow
- ✅ Partial order fills
- ✅ Platform fee (5%, max 10%)
- ✅ Admin fee withdrawal

---

## 🔐 Security

### EIP-712 Typed Signatures
All profile updates and achievement claims require cryptographically signed messages from authorized backend signers.

### Soulbound Enforcement
```solidity
function _update(address from, address to, ...) internal override {
    if (from != address(0) && to != address(0)) {
        revert SoulboundToken();
    }
    super._update(from, to, ids, values);
}
```

### Role-Based Access Control
| Role | Permissions |
|------|-------------|
| `ADMIN_ROLE` | Grant/revoke roles, update URIs |
| `BACKEND_SIGNER_ROLE` | Sign stats updates, achievement claims |
| `EVENT_MANAGER_ROLE` | Create/update events |

---

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- [Node.js](https://nodejs.org/) v16+ and pnpm
- Git

### Installation

```bash
# Clone repository
git clone https://github.com/Runera-Project/SmartContract.git
cd SmartContract

# Install dependencies
pnpm install

# Install Foundry dependencies
forge install
```

### Environment Setup

Copy `.env.example` to `.env` and configure:

```env
PRIVATE_KEY=your_private_key
DEPLOYER_ADDRESS=your_deployer_address
BACKEND_SIGNER_ADDRESS=your_backend_signer
EVENT_MANAGER_ADDRESS=your_event_manager
BASESCAN_API_KEY=your_api_key
```

### Build

```bash
forge build
```

---

## 📦 Deployment

### Deploy Complete Protocol

```bash
forge script script/DeployComplete.s.sol:DeployComplete \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

This deploys all 6 contracts:
1. RuneraAccessControl
2. RuneraEventRegistry
3. RuneraProfileDynamicNFT
4. RuneraAchievementDynamicNFT
5. RuneraCosmeticNFT
6. RuneraMarketplace

### Create Genesis Event

```bash
forge script script/CreateGenesisEvent.s.sol:CreateGenesisEvent \
  --rpc-url $RPC_URL \
  --broadcast
```

---

## 🧪 Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test test_Register

# Gas report
forge test --gas-report

# Test summary
forge test --summary
```

### Test Coverage

| Contract | Tests | Status |
|----------|-------|--------|
| RuneraAccessControl | 9 | ✅ |
| RuneraProfileDynamicNFT | 19 | ✅ |
| RuneraAchievementDynamicNFT | 15 | ✅ |
| RuneraEventRegistry | 16 | ✅ |
| RuneraCosmeticNFT | 26 | ✅ |
| RuneraMarketplace | 27 | ✅ |
| **Total** | **112** | ✅ |

---

## 📊 Project Structure

```
Runera/
├── src/
│   ├── RuneraProfileDynamicNFT.sol      # Layer 1: Identity
│   ├── RuneraAchievementDynamicNFT.sol  # Layer 2: Proof
│   ├── RuneraCosmeticNFT.sol            # Layer 3: Economy
│   ├── RuneraMarketplace.sol            # Layer 3: Trading
│   ├── RuneraEventRegistry.sol          # Event Management
│   ├── access/
│   │   └── RuneraAccessControl.sol      # Role Management
│   └── interfaces/                       # Contract Interfaces
├── test/                                 # Foundry Tests
├── script/
│   ├── DeployComplete.s.sol             # Full Deployment
│   └── CreateGenesisEvent.s.sol         # Genesis Event
├── foundry.toml                          # Foundry Config
└── package.json                          # NPM Dependencies
```

---

## 🌐 Target Networks

- **Arbitrum** - Layer 2 scaling
- **Base** - Coinbase L2
- **Mantle** - High-performance L2

---

## 📄 License

This project is licensed under the MIT License.

---

## 🔗 Links

- [Foundry Documentation](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [EIP-712 Specification](https://eips.ethereum.org/EIPS/eip-712)

---

**Built with Foundry** 🛠️ | **Secured by OpenZeppelin** 🔒 | **Optimized for EVM** ⚡
