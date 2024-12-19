# Transactional Key-Value Store

A persistent key-value database with ACID transaction support built in Elixir.

## Core Design Philosophy

The project follows a domain-driven design approach with clear boundaries between concerns. The system is built around four core concepts:

1. **Command Processing**: Converting raw text commands into structured operations
2. **Value Management**: Type handling and validation
3. **Storage**: Core persistence and atomic operations
4. **Transactions**: ACID guarantees and isolation

### Domain Model

The system is organized into focused modules, each with clear responsibilities:

#### CommandParser
- Acts as the entry point for all operations
- Handles command tokenization and validation
- Routes operations to appropriate handlers
- Coordinates between storage and transaction systems

#### ValueParser
- Provides type inference and validation
- Handles complex string processing (quotes, escapes)
- Enforces data type constraints
- Validates key naming rules

#### Storage
- Manages the core key-value store
- Provides atomic file-based operations
- Handles concurrent access
- Ensures persistence guarantees

#### Transaction
- Implements MVCC (Multi-Version Concurrency Control)
- Manages transaction lifecycle
- Provides isolation between clients
- Ensures atomicity of operations

### Data Storage Strategy

The system uses a deliberately simple storage approach:

1. **File-Based Storage**
   - Direct file serialization using Erlang term format
   - File-system level locking for atomicity
   - Single file for main storage
   - Separate transaction files per client

2. **Concurrency Control**
   - Optimistic concurrency using read validation
   - File-level locking for atomic operations
   - Transaction isolation through separate buffers
   - No global lock manager needed

3. **Transaction Management**
   - Transaction files track reads and writes
   - Commit-time validation of read sets
   - No blocking on read operations
   - Write conflicts detected at commit

## Design Trade-offs and Rationale

### Why File-Based Storage?

**Pros:**
- Simple to implement and understand
- Direct durability guarantees
- Easy backup and recovery
- Natural atomic operations through OS
- No external dependencies

**Cons:**
- Limited scalability for large datasets
- Performance impact from file I/O
- No built-in replication
- File system limits on concurrent access

### Why Optimistic Concurrency?

**Pros:**
- No blocking on reads
- Simple implementation
- Good performance for low contention
- Natural fit for MVCC
- Scales well for read-heavy workloads

**Cons:**
- Potential for transaction rollbacks
- Higher latency for write-heavy workloads
- Memory overhead for tracking reads
- Complexity in conflict resolution

### Why Separate Transaction Files?

**Pros:**
- Clean isolation between clients
- Simple crash recovery
- Easy to reason about transaction state
- Natural persistence of transaction data

**Cons:**
- File system overhead
- Cleanup requirements
- Limited by file system performance
- Potential for orphaned files

### Architecture Decisions

1. **No Process-Based Locking**
   - Chose file-based locking over process-based
   - Simpler crash recovery
   - Natural durability guarantees
   - Trade-off: Performance impact

2. **Optimistic Over Pessimistic**
   - No read locks required
   - Better scalability for typical workloads
   - Simpler implementation
   - Trade-off: Potential rollbacks

3. **Type System**
   - Strong type validation
   - Clear rules for type conversion
   - Predictable behavior
   - Trade-off: Some flexibility lost

4. **Command Interface**
   - Text-based for simplicity
   - Easy to extend
   - Human-readable
   - Trade-off: Parsing overhead

## Performance Characteristics

### Strengths
- Excellent read scalability
- Strong consistency guarantees
- Predictable behavior under load
- Clear failure modes
- Low memory overhead

### Limitations
- Write scalability limited by file I/O
- Concurrent writes may cause rollbacks
- File system bounds performance
- No built-in replication

## Future Considerations

While the current design serves its purpose well, several areas could be enhanced:

1. **Replication Support**
   - Leader-follower replication
   - Consensus-based clustering
   - Read replicas

2. **Performance Optimizations**
   - In-memory caching layer
   - Batch write operations
   - Background compaction

3. **Extended Features**
   - Secondary indices
   - Range queries
   - Expiration policies

4. **Monitoring and Operations**
   - Metrics collection
   - Performance monitoring
   - Automated backup

The system's modular design allows for these enhancements while maintaining its core simplicity and reliability guarantees.

## Setup and Running

### Option 1: Docker Environment

Prerequisites:
- Docker
- Docker Compose

Start the server:
```bash
# Build and run
docker-compose up --build -d
```

Run tests:
```bash
# Make test script executable
chmod +x run-tests.sh

# start docker-compose.test
docker compose -f docker-compose.test.yml up --build -d

# Run all tests
./run-tests.sh

# Test specific file
./run-tests.sh test/path/to/test_file.exs

# Run with coverage
./run-tests.sh coverage

```

### Option 2: Local Environment

Prerequisites:
- asdf version manager
- Erlang and Elixir plugins for asdf

Setup:
```bash
# Install required versions
asdf install

# Get dependencies
mix deps.get
mix deps.compile
```

Start the server:
```bash
# Development
mix phx.server

# Production
MIX_ENV=prod mix phx.server
```

## Using the API

The server accepts commands via HTTP POST requests. All commands use the following curl template:

```bash
curl -H 'Content-Type: text/plain' -H 'X-Client-Name: client1' -X POST -d '<COMMAND>' localhost:4444 -w '\n'
```

### Basic Operations

Set a value:
```bash
curl -H 'Content-Type: text/plain' -H 'X-Client-Name: client1' -X POST -d 'SET mykey 42' localhost:4444 -w '\n'
# Response: NIL 42
```

Get a value:
```bash
curl -H 'Content-Type: text/plain' -H 'X-Client-Name: client1' -X POST -d 'GET mykey' localhost:4444 -w '\n'
# Response: 42
```

### Transaction Operations

Begin transaction:
```bash
curl -H 'Content-Type: text/plain' -H 'X-Client-Name: client1' -X POST -d 'BEGIN' localhost:4444 -w '\n'
# Response: OK
```

Commit transaction:
```bash
curl -H 'Content-Type: text/plain' -H 'X-Client-Name: client1' -X POST -d 'COMMIT' localhost:4444 -w '\n'
# Response: OK
```

Rollback transaction:
```bash
curl -H 'Content-Type: text/plain' -H 'X-Client-Name: client1' -X POST -d 'ROLLBACK' localhost:4444 -w '\n'
# Response: OK
```

### Error Handling

Invalid key:
```bash
curl -H 'Content-Type: text/plain' -H 'X-Client-Name: client1' -X POST -d 'GET 10' localhost:4444 -w '\n'
# Response: ERR "Value 10 is not valid as key"
```

Invalid command:
```bash
curl -H 'Content-Type: text/plain' -H 'X-Client-Name: client1' -X POST -d 'SET' localhost:4444 -w '\n'
# Response: ERR "SET <key> <value> - Syntax error"
```
