# 🔧 Runera Backend Integration Guide

> **Complete Technical Handoff untuk Backend Team**  
> Dokumen ini berisi semua yang dibutuhkan untuk mengintegrasikan backend dengan Runera Smart Contracts.

---

## 📋 Table of Contents

1. [Tech Stack Requirements](#-tech-stack-requirements)
2. [Project Setup](#-project-setup)
3. [Smart Contract ABIs](#-smart-contract-abis)
4. [EIP-712 Signature Generation](#-eip-712-signature-generation)
5. [API Endpoints Specification](#-api-endpoints-specification)
6. [Database Schema](#-database-schema)
7. [Event Listener Setup](#-event-listener-setup)
8. [Deployment Checklist](#-deployment-checklist)

---

## 🛠 Tech Stack Requirements

### Core Stack (Recommended)

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Runtime** | Node.js | 20 LTS | Server runtime |
| **Language** | TypeScript | 5.x | Type safety |
| **Framework** | NestJS / Express | 10.x / 4.x | API framework |
| **Blockchain** | ethers.js | 6.x | Contract interaction |
| **Database** | PostgreSQL | 15+ | Primary data store |
| **Cache** | Redis | 7+ | Session & rate limiting |
| **Queue** | BullMQ | 4.x | Background jobs |

### Development Tools

```bash
# Package Manager
pnpm (recommended) or npm

# Code Quality
eslint + prettier
husky (git hooks)

# Testing
jest + supertest

# Documentation
swagger/openapi
```

### Infrastructure

| Service | Purpose |
|---------|---------|
| **RPC Provider** | Alchemy / QuickNode / Infura (Base chain) |
| **Wallet** | Hardware wallet atau KMS untuk production |
| **Monitoring** | Datadog / New Relic / Prometheus |
| **Logging** | Winston + ELK Stack |

---

## 🚀 Project Setup

### Step 1: Initialize Project

```bash
# Create project
mkdir runera-backend && cd runera-backend
pnpm init

# Install core dependencies
pnpm add ethers@6 express typescript @types/node @types/express
pnpm add dotenv zod prisma @prisma/client
pnpm add ioredis bullmq

# Install dev dependencies
pnpm add -D ts-node nodemon jest @types/jest
```

### Step 2: TypeScript Configuration

**tsconfig.json:**
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### Step 3: Environment Configuration

**.env:**
```ini
# Server
PORT=3000
NODE_ENV=development

# Blockchain
RPC_URL=https://sepolia.base.org
CHAIN_ID=84532

# Contract Addresses (from deployment)
ACCESS_CONTROL_ADDRESS=0x...
EVENT_REGISTRY_ADDRESS=0x...
PROFILE_NFT_ADDRESS=0x...
ACHIEVEMENT_NFT_ADDRESS=0x...
COSMETIC_NFT_ADDRESS=0x...
MARKETPLACE_ADDRESS=0x...

# Signer (CRITICAL - use KMS in production!)
BACKEND_SIGNER_PRIVATE_KEY=0x...

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/runera

# Redis
REDIS_URL=redis://localhost:6379
```

---

## 📜 Smart Contract ABIs

### Where to Get ABIs

After running `forge build`, ABIs are located in:
```
out/
├── RuneraProfileDynamicNFT.sol/
│   └── RuneraProfileDynamicNFT.json  ← Contains ABI
├── RuneraAchievementDynamicNFT.sol/
│   └── RuneraAchievementDynamicNFT.json
├── RuneraCosmeticNFT.sol/
│   └── RuneraCosmeticNFT.json
└── RuneraMarketplace.sol/
    └── RuneraMarketplace.json
```

### Extract ABIs

```bash
# Create abi folder
mkdir -p src/abi

# Extract ABIs (run from project root)
cat out/RuneraProfileDynamicNFT.sol/RuneraProfileDynamicNFT.json | jq '.abi' > src/abi/ProfileNFT.json
cat out/RuneraAchievementDynamicNFT.sol/RuneraAchievementDynamicNFT.json | jq '.abi' > src/abi/AchievementNFT.json
cat out/RuneraCosmeticNFT.sol/RuneraCosmeticNFT.json | jq '.abi' > src/abi/CosmeticNFT.json
cat out/RuneraMarketplace.sol/RuneraMarketplace.json | jq '.abi' > src/abi/Marketplace.json
```

---

## 🔐 EIP-712 Signature Generation

### Domain Separator Setup

```typescript
// src/lib/signer.ts
import { ethers } from 'ethers';

const DOMAIN = {
  name: 'RuneraProfileDynamicNFT', // atau 'RuneraAchievementDynamicNFT'
  version: '1',
  chainId: process.env.CHAIN_ID,
  verifyingContract: process.env.PROFILE_NFT_ADDRESS,
};
```

### Profile Stats Update Signature

```typescript
// TypeHash yang digunakan contract
const STATS_UPDATE_TYPEHASH = ethers.keccak256(
  ethers.toUtf8Bytes(
    'StatsUpdate(address user,uint256 xp,uint8 level,uint32 tasksCompleted,uint32 achievementCount,uint256 nonce,uint256 deadline)'
  )
);

// Function untuk generate signature
async function signStatsUpdate(
  signer: ethers.Wallet,
  user: string,
  xp: bigint,
  level: number,
  tasksCompleted: number,
  achievementCount: number,
  nonce: number,
  deadline: number
): Promise<string> {
  const domain = {
    name: 'RuneraProfileDynamicNFT',
    version: '1',
    chainId: parseInt(process.env.CHAIN_ID!),
    verifyingContract: process.env.PROFILE_NFT_ADDRESS,
  };

  const types = {
    StatsUpdate: [
      { name: 'user', type: 'address' },
      { name: 'xp', type: 'uint256' },
      { name: 'level', type: 'uint8' },
      { name: 'tasksCompleted', type: 'uint32' },
      { name: 'achievementCount', type: 'uint32' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
    ],
  };

  const value = {
    user,
    xp,
    level,
    tasksCompleted,
    achievementCount,
    nonce,
    deadline,
  };

  return await signer.signTypedData(domain, types, value);
}
```

### Achievement Claim Signature

```typescript
const CLAIM_TYPEHASH = ethers.keccak256(
  ethers.toUtf8Bytes(
    'ClaimAchievement(address to,bytes32 eventId,uint8 tier,bytes32 metadataHash,uint256 nonce,uint256 deadline)'
  )
);

async function signAchievementClaim(
  signer: ethers.Wallet,
  to: string,
  eventId: string,
  tier: number,
  metadataHash: string,
  nonce: number,
  deadline: number
): Promise<string> {
  const domain = {
    name: 'RuneraAchievementDynamicNFT',
    version: '1',
    chainId: parseInt(process.env.CHAIN_ID!),
    verifyingContract: process.env.ACHIEVEMENT_NFT_ADDRESS,
  };

  const types = {
    ClaimAchievement: [
      { name: 'to', type: 'address' },
      { name: 'eventId', type: 'bytes32' },
      { name: 'tier', type: 'uint8' },
      { name: 'metadataHash', type: 'bytes32' },
      { name: 'nonce', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
    ],
  };

  const value = {
    to,
    eventId,
    tier,
    metadataHash,
    nonce,
    deadline,
  };

  return await signer.signTypedData(domain, types, value);
}
```

---

## 🌐 API Endpoints Specification

### Profile Endpoints

```
POST   /api/v1/profile/register
       Body: { address: string }
       Response: { signature, deadline, nonce }

POST   /api/v1/profile/update-stats
       Body: { address, xp, level, tasks, achievements }
       Response: { signature, deadline, nonce }

GET    /api/v1/profile/:address
       Response: { profile, tier, tokenId }

GET    /api/v1/profile/:address/tier
       Response: { tier: 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM' | 'DIAMOND' }
```

### Achievement Endpoints

```
POST   /api/v1/achievement/claim
       Body: { address, eventId }
       Response: { signature, tier, deadline, nonce }

GET    /api/v1/achievement/:address
       Response: { achievements: Achievement[] }

GET    /api/v1/achievement/:address/:eventId
       Response: { achievement, tokenId }
```

### Cosmetic Endpoints

```
GET    /api/v1/cosmetic/catalog
       Query: ?category=SHOES&rarity=RARE
       Response: { items: CosmeticItem[] }

GET    /api/v1/cosmetic/:address/inventory
       Response: { items: OwnedItem[] }

GET    /api/v1/cosmetic/:address/equipped
       Response: { shoes, outfit, accessory, frame }

POST   /api/v1/cosmetic/mint
       Body: { address, itemId, amount }
       Auth: Admin only
```

### Marketplace Endpoints

```
GET    /api/v1/marketplace/listings
       Query: ?itemId=1&status=ACTIVE
       Response: { listings: Listing[] }

GET    /api/v1/marketplace/listings/:id
       Response: { listing }

GET    /api/v1/marketplace/seller/:address
       Response: { listings: Listing[] }
```

### Metadata Endpoints (for NFT display)

```
GET    /api/v1/metadata/profile/:tokenId
       Response: OpenSea-compatible JSON metadata

GET    /api/v1/metadata/achievement/:tokenId
       Response: OpenSea-compatible JSON metadata

GET    /api/v1/metadata/cosmetic/:itemId
       Response: OpenSea-compatible JSON metadata
```

---

## 🗃 Database Schema

### Prisma Schema

```prisma
// prisma/schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id              String    @id @default(cuid())
  walletAddress   String    @unique
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt

  profile         Profile?
  achievements    Achievement[]
  cosmetics       UserCosmetic[]
  listings        Listing[]
}

model Profile {
  id              String    @id @default(cuid())
  userId          String    @unique
  user            User      @relation(fields: [userId], references: [id])

  tokenId         String    @unique
  xp              BigInt    @default(0)
  level           Int       @default(1)
  tasksCompleted  Int       @default(0)
  achievementCount Int      @default(0)
  tier            Tier      @default(BRONZE)

  registeredAt    DateTime  @default(now())
  lastSyncedAt    DateTime  @default(now())
}

enum Tier {
  BRONZE
  SILVER
  GOLD
  PLATINUM
  DIAMOND
}

model Achievement {
  id              String    @id @default(cuid())
  userId          String
  user            User      @relation(fields: [userId], references: [id])

  tokenId         String    @unique
  eventId         String
  tier            Int
  unlockedAt      DateTime
  metadataHash    String

  @@unique([userId, eventId])
}

model CosmeticItem {
  id              String    @id @default(cuid())
  itemId          Int       @unique
  name            String
  category        Category
  rarity          Rarity
  ipfsHash        String
  maxSupply       Int
  currentSupply   Int       @default(0)
  minTierRequired Int       @default(0)

  owners          UserCosmetic[]
}

enum Category {
  SHOES
  OUTFIT
  ACCESSORY
  FRAME
}

enum Rarity {
  COMMON
  RARE
  EPIC
  LEGENDARY
  MYTHIC
}

model UserCosmetic {
  id              String    @id @default(cuid())
  userId          String
  user            User      @relation(fields: [userId], references: [id])
  itemId          String
  item            CosmeticItem @relation(fields: [itemId], references: [id])
  quantity        Int       @default(1)

  equippedSlot    Category?

  @@unique([userId, itemId])
}

model Listing {
  id              String    @id @default(cuid())
  listingId       Int       @unique
  sellerId        String
  seller          User      @relation(fields: [sellerId], references: [id])

  itemId          Int
  amount          Int
  pricePerUnit    BigInt
  status          ListingStatus @default(ACTIVE)

  createdAt       DateTime  @default(now())
  soldAt          DateTime?
}

enum ListingStatus {
  ACTIVE
  SOLD
  CANCELLED
}
```

### Initialize Database

```bash
# Generate Prisma client
pnpm prisma generate

# Run migrations
pnpm prisma migrate dev --name init

# Seed initial data (optional)
pnpm prisma db seed
```

---

## 📡 Event Listener Setup

### Blockchain Event Indexer

```typescript
// src/indexer/index.ts
import { ethers } from 'ethers';
import ProfileABI from '../abi/ProfileNFT.json';
import AchievementABI from '../abi/AchievementNFT.json';

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);

// Profile NFT Events
const profileContract = new ethers.Contract(
  process.env.PROFILE_NFT_ADDRESS!,
  ProfileABI,
  provider
);

profileContract.on('ProfileRegistered', async (user, tokenId, event) => {
  console.log(`New profile: ${user} -> Token ${tokenId}`);
  // Sync to database
  await prisma.profile.upsert({
    where: { tokenId: tokenId.toString() },
    create: {
      tokenId: tokenId.toString(),
      user: { connectOrCreate: { where: { walletAddress: user }, create: { walletAddress: user } } },
    },
    update: {},
  });
});

profileContract.on('StatsUpdated', async (user, xp, level, tasks, achievements, event) => {
  console.log(`Stats updated: ${user}`);
  await prisma.profile.update({
    where: { user: { walletAddress: user } },
    data: { xp, level, tasksCompleted: tasks, achievementCount: achievements },
  });
});

profileContract.on('TierUpgraded', async (user, oldTier, newTier, event) => {
  console.log(`Tier upgrade: ${user} ${oldTier} -> ${newTier}`);
  // Trigger rewards, notifications, etc.
});

// Achievement NFT Events
const achievementContract = new ethers.Contract(
  process.env.ACHIEVEMENT_NFT_ADDRESS!,
  AchievementABI,
  provider
);

achievementContract.on('AchievementClaimed', async (user, eventId, tier, event) => {
  console.log(`Achievement claimed: ${user} for event ${eventId}`);
  // Sync to database
});

// Keep process alive
process.on('SIGINT', () => {
  provider.removeAllListeners();
  process.exit();
});
```

### Running Indexer

```bash
# Development
pnpm ts-node src/indexer/index.ts

# Production (use PM2)
pm2 start dist/indexer/index.js --name "runera-indexer"
```

---

## ✅ Deployment Checklist

### Pre-Deployment

- [ ] All contract addresses configured in `.env`
- [ ] Private key stored securely (KMS recommended)
- [ ] Database migrated and seeded
- [ ] Redis running
- [ ] RPC endpoint tested

### Security

- [ ] Rate limiting enabled
- [ ] CORS configured
- [ ] Helmet.js middleware added
- [ ] Input validation (Zod)
- [ ] Signature deadline < 5 minutes
- [ ] Private key NOT in code

### Monitoring

- [ ] Health check endpoint `/health`
- [ ] Prometheus metrics `/metrics`
- [ ] Error tracking (Sentry)
- [ ] Blockchain event lag monitoring

### Testing

- [ ] Unit tests for signature generation
- [ ] Integration tests with testnet
- [ ] Load testing for API endpoints

---

## 📚 Additional Resources

- [ethers.js v6 Docs](https://docs.ethers.org/v6/)
- [EIP-712 Specification](https://eips.ethereum.org/EIPS/eip-712)
- [Base Chain Docs](https://docs.base.org/)
- [OpenSea Metadata Standards](https://docs.opensea.io/docs/metadata-standards)

---

**Questions?** Contact the smart contract team untuk klarifikasi signature format atau contract behavior.
