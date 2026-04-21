# Changelog
This file contains all the notable changes done to the Ballerina `ai.memory.redis` package through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial implementation of the Redis-backed short-term memory store for AI messages
- Support for system and interactive message separation using Redis `SET` and `RPUSH`
- Configurable `maxMessagesPerKey` limit with enforcement
- Optional in-memory cache layer via `ballerina/cache`
- Support for custom `keyPrefix` per store instance
- `isFull()` and `getCapacity()` utility methods
- GraalVM native image compatibility
