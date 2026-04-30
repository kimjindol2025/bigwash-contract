# BigWash Contract System - Execution Guide

## Setup
The system is built with FreeLang v11.

## How to Run

### 1. Initialize Database
The database is automatically initialized when running `db.fl` or any file that loads it.
```bash
node /root/kim/freelang-v11/bootstrap.js run /root/bigwash-contract/src/db.fl
```

### 2. Run Tests
```bash
node /root/kim/freelang-v11/bootstrap.js run /root/bigwash-contract/tests/test_contract.fl
```

### 3. Start API Server
```bash
node /root/kim/freelang-v11/bootstrap.js run /root/bigwash-contract/src/api.fl
```

## API Endpoints
- `GET /contracts`: List contracts (optional query `status`)
- `GET /contracts/:id`: Get contract details
- `POST /contracts`: Create a new contract
- `PUT /contracts/:id`: Update contract status
