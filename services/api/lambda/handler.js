'use strict';

const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');
const { marshall } = require('@aws-sdk/util-dynamodb');
const crypto = require('crypto');

// Demo API, not the full system in docs/API.md. Real device auth there is
// App Attest + Cognito (docs/DELIVERY_PLAN.md Track D), which needs an
// enrolled physical device and is out of scope while the Apple entitlement
// is pending. This swaps that for one static bearer token so the client
// can still demonstrate a real network round trip.
const DEMO_TOKEN = process.env.DEMO_API_TOKEN;
const TABLE_NAME = process.env.TABLE_NAME;
const ORG_ID = 'org_demo';
const VENUE_ID = 'v_demo';
const DEVICE_ID = 'dev_demo';

const ddb = new DynamoDBClient({});

// One hardcoded roster, standing in for PR-19's shift-claim endpoint.
const STAFF_BY_PIN = {
  '1234': { staffId: 'stf_alex', name: 'Alex' },
  '5678': { staffId: 'stf_jordan', name: 'Jordan' },
};

const CONFIG_RESPONSE = {
  version: 1,
  supportedJurisdictions: ['AZ', 'CA', 'CO', 'GA', 'HI', 'IA', 'MD', 'MT', 'NM', 'OH', 'PR', 'WV'],
  minimumAge: 21,
  requestedElements: ['age_at_least_21', 'portrait', 'given_name', 'family_name'],
  shiftIdleTimeoutMinutes: 600,
  outboxWarnThreshold: 10000,
  flags: { railEnabled: true, mockRailAllowed: true },
};

const jsonResponse = (statusCode, body, extraHeaders = {}) => ({
  statusCode,
  headers: {
    'content-type': 'application/json',
    'access-control-allow-origin': '*',
    ...extraHeaders,
  },
  body: JSON.stringify(body),
});

const errorResponse = (statusCode, code, message, requestId, retryable = false) =>
  jsonResponse(statusCode, {
    error: { code, message, retryable, requestId },
  });

function requireAuth(event, requestId) {
  const header = event.headers?.authorization ?? event.headers?.Authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice('Bearer '.length) : null;
  if (!DEMO_TOKEN || token !== DEMO_TOKEN) {
    return errorResponse(401, 'attestation_invalid', 'Missing or invalid demo bearer token.', requestId);
  }
  return null;
}

async function handleClaimShift(event, requestId) {
  let payload;
  try {
    payload = JSON.parse(event.body ?? '{}');
  } catch {
    return errorResponse(400, 'malformed_request', 'Body must be JSON.', requestId);
  }

  const staff = STAFF_BY_PIN[payload.pin];
  if (!staff) {
    return errorResponse(401, 'shift_pin_invalid', 'PIN not recognized.', requestId);
  }

  const shiftId = `sft_${crypto.randomUUID().slice(0, 8)}`;
  const startedAt = new Date().toISOString();

  await ddb.send(
    new PutItemCommand({
      TableName: TABLE_NAME,
      Item: marshall({
        PK: `VENUE#${VENUE_ID}`,
        SK: `SHIFT#${startedAt}#${shiftId}`,
        type: 'Shift',
        orgId: ORG_ID,
        venueId: VENUE_ID,
        deviceId: DEVICE_ID,
        staffId: staff.staffId,
        startedAt,
        endedAt: null,
        endedBy: null,
        eventCount: 0,
        GSI3PK: `STAFF#${staff.staffId}`,
        GSI3SK: `SHIFT#${startedAt}`,
      }),
    }),
  );

  return jsonResponse(200, {
    shiftId,
    staffId: staff.staffId,
    staffName: staff.name,
    venueId: VENUE_ID,
    startedAt,
  });
}

async function putEventIdempotent(evt, requestId) {
  const occurredAt = evt.occurredAt ?? new Date().toISOString();
  const day = occurredAt.slice(0, 10);
  const receivedAt = new Date().toISOString();
  const clockSkewMs = Date.parse(receivedAt) - Date.parse(occurredAt);

  const item = {
    PK: `VENUE#${VENUE_ID}#${day}`,
    SK: `EVT#${evt.eventId}`,
    type: 'VerificationEvent',
    orgId: ORG_ID,
    venueId: VENUE_ID,
    deviceId: DEVICE_ID,
    shiftId: evt.shiftId,
    railResult: evt.railResult,
    ageAtLeast21: evt.ageAtLeast21 ?? null,
    humanDecision: evt.humanDecision ?? null,
    refusalReason: evt.refusalReason ?? null,
    issuingJurisdiction: evt.issuingJurisdiction ?? null,
    occurredAt,
    receivedAt,
    clockSkewMs,
    readLatencyMs: evt.readLatencyMs ?? null,
    syncedOffline: evt.syncedOffline ?? false,
    GSI1PK: `ORG#${ORG_ID}`,
    GSI1SK: `EVT#${occurredAt}`,
    GSI2PK: `DEVICE#${DEVICE_ID}`,
    GSI2SK: `EVT#${occurredAt}`,
  };

  try {
    await ddb.send(
      new PutItemCommand({
        TableName: TABLE_NAME,
        Item: marshall(item, { removeUndefinedValues: true }),
        ConditionExpression: 'attribute_not_exists(PK)',
      }),
    );
    return { eventId: evt.eventId, status: 'accepted' };
  } catch (err) {
    if (err.name === 'ConditionalCheckFailedException') {
      return { eventId: evt.eventId, status: 'duplicate' };
    }
    console.error('event write failed', requestId, evt.eventId, err);
    return {
      eventId: evt.eventId,
      status: 'rejected',
      error: { code: 'internal', retryable: true },
    };
  }
}

async function handleEvents(event, requestId) {
  let payload;
  try {
    payload = JSON.parse(event.body ?? '{}');
  } catch {
    return errorResponse(400, 'malformed_request', 'Body must be JSON.', requestId);
  }

  const events = Array.isArray(payload.events) ? payload.events : [];
  if (events.length === 0) {
    return errorResponse(400, 'malformed_request', 'events[] is required.', requestId);
  }

  const results = [];
  for (const evt of events) {
    if (!evt.eventId || !evt.railResult) {
      results.push({
        eventId: evt.eventId ?? null,
        status: 'rejected',
        error: { code: 'malformed_event', retryable: false },
      });
      continue;
    }
    results.push(await putEventIdempotent(evt, requestId));
  }

  return jsonResponse(200, { results });
}

exports.handler = async (event) => {
  const requestId = event.requestContext?.requestId ?? crypto.randomUUID();
  const method = event.requestContext?.http?.method ?? event.httpMethod;
  const path = event.rawPath ?? event.requestContext?.http?.path ?? '';

  if (method === 'OPTIONS') {
    return jsonResponse(204, {}, {
      'access-control-allow-headers': 'authorization,content-type',
      'access-control-allow-methods': 'GET,POST,OPTIONS',
    });
  }

  try {
    if (method === 'GET' && path === '/v1/config') {
      return jsonResponse(200, CONFIG_RESPONSE);
    }

    const authError = requireAuth(event, requestId);
    if (authError) return authError;

    if (method === 'POST' && path === '/v1/shifts') {
      return await handleClaimShift(event, requestId);
    }

    if (method === 'POST' && path === '/v1/events') {
      return await handleEvents(event, requestId);
    }

    return errorResponse(404, 'not_found', `No route for ${method} ${path}`, requestId);
  } catch (err) {
    console.error('unhandled error', requestId, err);
    return errorResponse(500, 'internal', 'Unexpected server error.', requestId, true);
  }
};
