## Overview

This module provides a Redis-backed short-term memory store to use with AI messages (e.g., with AI agents, model providers, etc.).

### Key Features

- Redis-backed persistent storage for short-term AI message memory
- Separate storage for system messages (`SET`/`GET`) and interactive messages (`RPUSH`/`LRANGE`)
- Configurable maximum messages per key with automatic enforcement
- Built-in in-memory caching for improved read performance
- Configurable key prefix for multi-tenant or multi-application isolation
- Support for both connection configuration and existing `redis:Client` reuse

## Prerequisites

- A running Redis server (local or cloud-hosted)

## Quickstart

Follow the steps below to use this store in your Ballerina application:

1. Import the `ballerinax/ai.memory.redis` module.

```ballerina
import ballerinax/ai.memory.redis;
```

Optionally, import the `ballerina/ai` and/or `ballerinax/redis` module(s).

```ballerina
import ballerina/ai;
import ballerinax/redis;
```

2. Create the short-term memory store by passing either the connection configuration or a `redis:Client`.

    i. Using the connection configuration

    ```ballerina
    import ballerina/ai;
    import ballerinax/ai.memory.redis;

    configurable string host = ?;
    configurable int port = ?;

    ai:ShortTermMemoryStore store = check new redis:ShortTermMemoryStore({
        host, port
    });
    ```

    ii. Using an existing `redis:Client`

    ```ballerina
    import ballerina/ai;
    import ballerinax/redis;
    import ballerinax/ai.memory.redis as redisStore;

    configurable string host = ?;
    configurable int port = ?;

    redis:Client redisClient = check new redis:Client(connection = {host, port});
    ai:ShortTermMemoryStore store = check new redisStore:ShortTermMemoryStore(redisClient);
    ```

    Optionally, specify the maximum number of messages per key (`maxMessagesPerKey` - defaults to `20`), the in-memory cache configuration (`cacheConfig`), and a custom key prefix (`keyPrefix` - defaults to `"chat_memory"`).

    ```ballerina
    ai:ShortTermMemoryStore store = check new redis:ShortTermMemoryStore({
        host, port
    }, 10, {capacity: 10}, "my_app_memory");
    ```
