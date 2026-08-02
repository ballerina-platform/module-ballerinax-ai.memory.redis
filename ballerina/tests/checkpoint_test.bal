// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/ai;
import ballerina/test;
import ballerina/time;
import ballerinax/redis;

const string SESSION1 = "session1";
const string SESSION2 = "session2";

function cleanupCheckpointKeys() returns error? {
    redis:Client cl = getClient();
    _ = check cl->del([
        KEY_PREFIX + ":" + SESSION1 + ":checkpoint",
        KEY_PREFIX + ":" + SESSION2 + ":checkpoint"
    ]);
}

function buildPendingApproval(string sessionId) returns ai:PendingApproval {
    time:Utc now = time:utcNow();
    return {
        sessionId,
        executionId: "exec-1",
        iterationsUsed: 2,
        history: [
            {role: ai:SYSTEM, content: "You are a helpful assistant."},
            {role: ai:USER, content: "Please refund order ORD-1001."}
        ],
        historyPrefixLength: 1,
        iterations: [
            {
                history: [{role: ai:USER, content: "Please refund order ORD-1001."}],
                output: [
                    {role: ai:ASSISTANT, content: (), toolCalls: [{name: "issueRefund", arguments: {"orderId": "ORD-1001"}}]},
                    error ai:Error("tool execution paused for approval")
                ],
                startTime: now,
                endTime: now
            }
        ],
        toolCalls: [{name: "issueRefund", arguments: {"orderId": "ORD-1001"}, id: "call-1"}],
        startTime: now,
        originalBatch: [{name: "issueRefund", arguments: {"orderId": "ORD-1001"}, id: "call-1"}],
        pendingRequests: [
            {
                id: "req-1",
                sessionId,
                toolName: "issueRefund",
                toolDescription: "Issues a refund for an order",
                arguments: {"orderId": "ORD-1001"},
                toolCallId: "call-1",
                batchIndex: 0
            }
        ],
        decisions: [()]
    };
}

function assertPendingApprovalEquals(ai:PendingApproval actual, ai:PendingApproval expected) {
    test:assertEquals(actual.sessionId, expected.sessionId);
    test:assertEquals(actual.executionId, expected.executionId);
    test:assertEquals(actual.iterationsUsed, expected.iterationsUsed);
    test:assertEquals(actual.history.length(), expected.history.length());
    foreach int i in 0 ..< actual.history.length() {
        assertChatMessageEquals(actual.history[i], expected.history[i]);
    }
    test:assertEquals(actual.historyPrefixLength, expected.historyPrefixLength);
    test:assertEquals(actual.iterations.length(), expected.iterations.length());
    foreach int i in 0 ..< actual.iterations.length() {
        ai:Iteration actualIteration = actual.iterations[i];
        ai:Iteration expectedIteration = expected.iterations[i];
        test:assertEquals(actualIteration.output.length(), expectedIteration.output.length());
        foreach int j in 0 ..< actualIteration.output.length() {
            ai:ChatAssistantMessage|ai:ChatFunctionMessage|ai:Error actualOutput = actualIteration.output[j];
            ai:ChatAssistantMessage|ai:ChatFunctionMessage|ai:Error expectedOutput = expectedIteration.output[j];
            if expectedOutput is ai:Error {
                test:assertTrue(actualOutput is ai:Error);
                test:assertEquals((<ai:Error>actualOutput).message(), expectedOutput.message());
            } else {
                test:assertEquals(actualOutput, expectedOutput);
            }
        }
    }
    test:assertEquals(actual.toolCalls, expected.toolCalls);
    test:assertEquals(actual.originalBatch, expected.originalBatch);
    test:assertEquals(actual.pendingRequests, expected.pendingRequests);
    test:assertEquals(actual.decisions, expected.decisions);
}

@test:Config {
    before: cleanupCheckpointKeys
}
function testPutAndGetCheckpoint() returns error? {
    redis:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    test:assertEquals(check store.getCheckpoint(SESSION1), ());

    ai:PendingApproval approval = buildPendingApproval(SESSION1);
    check store.putCheckpoint(approval);

    ai:PendingApproval? retrieved = check store.getCheckpoint(SESSION1);
    if retrieved is () {
        test:assertFail("Expected a pending approval to be stored");
    }
    assertPendingApprovalEquals(retrieved, approval);

    // A different session should remain unaffected.
    test:assertEquals(check store.getCheckpoint(SESSION2), ());
}

@test:Config {
    before: cleanupCheckpointKeys
}
function testPutCheckpointReplacesExisting() returns error? {
    redis:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    ai:PendingApproval approval1 = buildPendingApproval(SESSION1);
    check store.putCheckpoint(approval1);

    ai:PendingApproval approval2 = buildPendingApproval(SESSION1);
    approval2.executionId = "exec-2";
    check store.putCheckpoint(approval2);

    ai:PendingApproval? retrieved = check store.getCheckpoint(SESSION1);
    if retrieved is () {
        test:assertFail("Expected a pending approval to be stored");
    }
    test:assertEquals(retrieved.executionId, "exec-2");
}

@test:Config {
    before: cleanupCheckpointKeys
}
function testRemoveCheckpoint() returns error? {
    redis:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    check store.putCheckpoint(buildPendingApproval(SESSION1));
    check store.removeCheckpoint(SESSION1);
    test:assertEquals(check store.getCheckpoint(SESSION1), ());

    // Removing a checkpoint that doesn't exist should be a no-op, not an error.
    check store.removeCheckpoint(SESSION1);
}

@test:Config {
    before: cleanupCheckpointKeys
}
function testTakeCheckpoint() returns error? {
    redis:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    test:assertEquals(check store.takeCheckpoint(SESSION1), ());

    ai:PendingApproval approval = buildPendingApproval(SESSION1);
    check store.putCheckpoint(approval);

    ai:PendingApproval? taken = check store.takeCheckpoint(SESSION1);
    if taken is () {
        test:assertFail("Expected a pending approval to be claimed");
    }
    assertPendingApprovalEquals(taken, approval);

    // The checkpoint should no longer be present after being taken.
    test:assertEquals(check store.getCheckpoint(SESSION1), ());
    test:assertEquals(check store.takeCheckpoint(SESSION1), ());
}

@test:Config {
    before: cleanupCheckpointKeys
}
function testRemoveAllAlsoClearsCheckpoint() returns error? {
    redis:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    check store.put(SESSION1, K1SM1);
    check store.putCheckpoint(buildPendingApproval(SESSION1));

    check store.removeAll(SESSION1);

    test:assertEquals(check store.getChatSystemMessage(SESSION1), ());
    test:assertEquals(check store.getCheckpoint(SESSION1), ());
}
