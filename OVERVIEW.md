# AT Protocol Lexicon Implementation Analysis - JavaScript Reference
Offical documentions found at https://atproto.com/guides/lexicon
Offical specs found at https://atproto.com/specs/lexicon


## Overview
The AT Protocol lexicon is a schema definition language for describing data structures, RPC methods, and database records in the Bluesky/AT Protocol ecosystem. The JavaScript implementation uses:
- **Zod** for schema validation (v3.23.8+)
- **Runtime parsing** approach (no code generation)
- **Modular architecture** with separate validators for different types
- **Type-safe TypeScript** throughout

## Repository Structure

Offical source repo can be found locally at `/home/josh/Dev/aether/bsky/atproto/`


## Lexcion app source structure from repo:
```
packages/lexicon/src/
├── index.ts              # Main exports
├── types.ts              # All Zod schema definitions & TypeScript types
├── lexicons.ts           # Lexicons collection & lookup class
├── validation.ts         # High-level validation orchestration
├── serialize.ts          # IPLD/JSON serialization conversions
├── blob-refs.ts          # Blob reference handling
├── util.ts               # Utilities (URI normalization, refinements)
└── validators/
    ├── primitives.ts     # boolean, integer, string, bytes, cid-link, unknown
    ├── complex.ts        # object, array, union handling
    ├── formats.ts        # Format validators (datetime, uri, did, handle, etc)
    ├── blob.ts           # Blob validation
    └── xrpc.ts           # XRPC parameters validation
```

## Lexicon json defintions:
location: `priv/spec`

## Core Architecture Patterns

### 1. Runtime Parsing (Not Code Generation)
- **No code generation step**
- Lexicons are parsed at runtime using Zod validators
- JSON lexicon files are directly validated and stored
- Validation happens through a `Lexicons` collection class
- Supports dynamic lexicon addition/removal at runtime

### 2. Main Entry Point: Lexicons Class

```typescript
// Located in: lexicons.ts
export class Lexicons implements Iterable<LexiconDoc> {
  docs: Map<string, LexiconDoc> = new Map()
  defs: Map<string, LexUserType> = new Map()

  // Key methods:
  add(doc: LexiconDoc): void              // Add a lexicon
  get(uri: string): LexiconDoc | undefined
  getDef(uri: string): LexUserType | undefined
  getDefOrThrow(uri, types?): LexUserType

  // Validation methods:
  validate(lexUri: string, value: unknown): ValidationResult
  assertValidRecord(lexUri: string, value: unknown)
  assertValidXrpcParams(lexUri: string, value: unknown)
  assertValidXrpcInput(lexUri: string, value: unknown)
  assertValidXrpcOutput(lexUri: string, value: unknown)
  assertValidXrpcMessage(lexUri: string, value: unknown)
}
```

### 3. URI Resolution & Reference System (will be implemented in other abtractions)
- **Namespace IDs (NSIDs)**: `com.example.schema` format
- **URIs with definitions**: `lex:com.example.schema#objectName`
- **Local references**: `#objectName` (resolved relative to base doc)
- **Implicit #main**: `com.example.schema` equals `com.example.schema#main`
- **Automatic resolution**: References are normalized and resolved at add-time

## JSON Lexicon Format

### Root Structure
```json
{
  "lexicon": 1,                          // Version (always 1)
  "id": "com.example.namespace",         // NSID identifier (required)
  "revision": 1,                         // Optional version number
  "description": "A description",        // Optional
  "defs": {                              // Named definitions
    "main": { ... },                     // Main definition (if record/query/procedure)
    "objectName": { ... }                // Additional type definitions
  }
}
```

### Definition Types (discriminated by "type" field)

#### 1. Primitives (in types.ts)

**Boolean**
```json
{
  "type": "boolean",
  "description": "Optional description",
  "default": true,
  "const": true
}
```

**Integer**
```json
{
  "type": "integer",
  "description": "Optional",
  "minimum": 0,
  "maximum": 100,
  "enum": [1, 2, 3],
  "default": 0,
  "const": 5
}
```

**String**
```json
{
  "type": "string",
  "description": "Optional",
  "minLength": 1,
  "maxLength": 256,
  "minGraphemes": 1,
  "maxGraphemes": 100,
  "format": "uri|datetime|did|handle|at-uri|at-identifier|nsid|cid|language|tid|record-key",
  "enum": ["a", "b"],
  "default": "value",
  "const": "fixed",
  "knownValues": ["a", "b"]  // Documentation hint
}
```

**Unknown**
```json
{
  "type": "unknown",
  "description": "Any JSON value"
}
```

#### 2. IPLD Types

**Bytes**
```json
{
  "type": "bytes",
  "description": "Optional",
  "minLength": 0,
  "maxLength": 1048576
}
```

**CID Link**
```json
{
  "type": "cid-link",
  "description": "Optional"
}
```

#### 3. References

**Single Reference**
```json
{
  "type": "ref",
  "description": "Optional",
  "ref": "#objectName"  // or "com.example.other#objectName"
}
```

**Union**
```json
{
  "type": "union",
  "description": "Optional",
  "refs": ["#type1", "#type2"],
  "closed": true  // If false, unknown types in union are allowed
}
```

#### 4. Complex Types

**Array**
```json
{
  "type": "array",
  "description": "Optional",
  "items": { "type": "string" },  // Any type allowed
  "minLength": 0,
  "maxLength": 10000
}
```

**Object**
```json
{
  "type": "object",
  "description": "Optional",
  "required": ["field1", "field2"],
  "nullable": ["field3"],  // Can be null
  "properties": {
    "field1": { "type": "string" },
    "field2": { "type": "integer" },
    "nested": { "type": "ref", "ref": "#nestedType" }
  }
}
```

**Token**
```json
{
  "type": "token",
  "description": "Empty marker type"
}
```

**Blob**
```json
{
  "type": "blob",
  "description": "Optional",
  "accept": ["image/jpeg", "image/png"],
  "maxSize": 1000000
}
```

#### 5. RPC Methods (XRPC)

**Query** (read-only)
```json
{
  "type": "query",
  "description": "Optional",
  "parameters": {
    "type": "params",
    "required": ["param1"],
    "properties": {
      "param1": { "type": "string" }
    }
  },
  "output": {
    "encoding": "application/json",
    "schema": { "type": "ref", "ref": "com.example.output" }
  },
  "errors": [
    { "name": "BadRequest", "description": "Invalid input" }
  ]
}
```

**Procedure** (read-write)
```json
{
  "type": "procedure",
  "description": "Optional",
  "parameters": { ... },
  "input": {
    "encoding": "application/json",
    "schema": { "type": "ref", "ref": "com.example.input" }
  },
  "output": { ... },
  "errors": [ ... ]
}
```

**Subscription**
```json
{
  "type": "subscription",
  "description": "Optional",
  "parameters": { ... },
  "message": {
    "schema": { "type": "ref", "ref": "com.example.message" }
  },
  "errors": [ ... ]
}
```

#### 6. Database

**Record**
```json
{
  "type": "record",
  "description": "Optional",
  "key": "tid",  // Storage key field
  "record": { "type": "object", ... }
}
```

**Permission Set** (rarely used)
```json
{
  "type": "permission-set",
  "description": "Optional",
  "title": "Title",
  "title:lang": { "en": "English Title" },
  "detail": "Details",
  "detail:lang": { ... },
  "permissions": [ ... ]
}
```

## Validation System

### Validation Flow

```
Input Value
    ↓
├─ Type check (correct data type)
│   ↓
├─ Required fields check
│   ↓
├─ Constraint validation
│   ├─ Min/max (length, value, graphemes)
│   ├─ Enum validation
│   ├─ Const validation
│   └─ Format validation
│   ↓
├─ Reference resolution (for ref/union types)
│   ↓
└─ Recursive validation (for nested objects/arrays)
```

### Constraint Validation Rules

#### String Constraints (primitives.ts)

1. **Length Constraints** (minLength, maxLength)
   - Measured in UTF-8 bytes
   - Optimization: Uses JavaScript string.length * 3 as upper bound first
   - Calls utf8Len() for precise validation when needed
   - Fast-path: skips UTF-8 check if JS length already within bounds

2. **Grapheme Constraints** (minGraphemes, maxGraphemes)
   - Counts extended grapheme clusters (handles emoji, combining marks)
   - Optimization: Skips check if JS length passes constraint
   - Uses graphemeLen() library function for precise count

3. **Format Validation** (formats.ts)
   - `datetime`: ISO 8601 / RFC 3339 (uses iso-datestring-validator)
   - `uri`: Protocol format regex: `\w+:(?:\/\/)?[^\s/][^\s]*`
   - `at-uri`: AT Protocol URI (at://did/ns/key)
   - `did`: Decentralized Identifier (did:method:specific-id)
   - `handle`: DNS-like handles (domain validation)
   - `at-identifier`: Either did or handle
   - `nsid`: Namespace ID (com.example.namespace format)
   - `cid`: Content ID (multiformats/cid parser)
   - `language`: BCP 47 language tags
   - `tid`: AT Protocol timestamp ID
   - `record-key`: Valid record key format

4. **Enum/Const** validation
   - Direct membership check for enums
   - Equality check for const

#### Integer Constraints (primitives.ts)

1. **Type check**: Must be Number.isInteger(value)
2. **Range**: minimum, maximum (inclusive)
3. **Enum/Const**: Same as strings
4. **Default**: Applied if undefined

#### Boolean Constraints (primitives.ts)

1. **Type check**: Must be boolean
2. **Const**: If specified, must match
3. **Default**: Applied if undefined

#### Array Constraints (complex.ts)

1. **Type check**: Must be Array
2. **Length constraints**: minLength, maxLength (element count)
3. **Item validation**: Each item validated against items schema
4. **Item paths**: `path/0`, `path/1`, etc. for error reporting

#### Object Constraints (complex.ts)

1. **Type check**: Must be object
2. **Required fields**: All required fields must be present
3. **Nullable fields**: Listed fields can be null
4. **Property validation**: Each property validated against its schema
5. **Default values**: Applied to missing non-required fields
6. **Unknown fields**: Allowed (JSON schema style)

#### Bytes Constraints (primitives.ts)

1. **Type check**: Must be Uint8Array instance
2. **Length**: minLength, maxLength (in bytes)

#### CID Link Validation (primitives.ts)

1. Validates using multiformats CID.asCID()

### Reference and Union Validation (complex.ts)

**Single Reference (type: "ref")**
- Looks up referenced definition in Lexicons collection
- Validates value against referenced type
- Resolves implicit #main references

**Union (type: "union")**
- Requires object with `$type` property
- Checks `$type` matches one of refs (normalized URIs)
- If `closed: false`: Unknown types allowed (pass through)
- If `closed: true`: Only listed refs allowed, otherwise error
- Handles both explicit and implicit #main references

### Error Handling

**ValidationResult<V>**
```typescript
type ValidationResult<V = unknown> =
  | { success: true; value: V }
  | { success: false; error: ValidationError }

class ValidationError extends Error {}
class InvalidLexiconError extends Error {}
class LexiconDefNotFoundError extends Error {}
```

**Error Messages** include:
- Path to field with error (e.g., "Record/object/name")
- Type mismatch description
- Constraint violation details
- Suggestion of valid values for enums

## Key Implementation Details

### 1. Optimization Strategies

**String Length Validation** (in primitives.ts)
```typescript
// Fast path: JS string length (UTF-16) might be sufficient
if (value.length * 3 <= def.maxLength) {
  // Can skip UTF-8 check since UTF-8 len <= JS len * 3
  canSkipUtf8LenChecks = true
}
```

**Default Values**
- Applied during validation, not stored in schema
- Shallow clone objects when applying defaults to avoid mutations
- Only primitives have defaults (integer, boolean, string)

**Lazy Object Cloning**
- Only clones objects when defaults are applied
- Preserves object identity when no changes made

### 2. Type System (Zod-Based)

**Custom Type Union** (lexUserType)
- Uses z.custom() instead of z.union() for performance
- Manual dispatch on type field with explicit parsing
- Avoids slowdown from discriminated unions (see comment in types.ts #915)

**Schema Refinements** (util.ts)
```typescript
function requiredPropertiesRefinement(object, ctx) {
  // Validates that required fields are defined in properties
  // Runs at schema parse time, not validation time
}
```

### 3. Serialization (serialize.ts)

**Four conversion types:**
1. `lexToIpld()`: Lex values → IPLD (handles BlobRef conversion)
2. `ipldToLex()`: IPLD → Lex values (reconstructs BlobRef)
3. `lexToJson()`: Lex → JSON (for JSON.stringify)
4. `jsonToLex()`: JSON → Lex

**BlobRef Handling:**
- Two JSON formats: typed `{$type: "blob", ref, mimeType, size}` and untyped `{cid, mimeType}`
- Runtime class wrapping with CID instances
- Preserves original encoding to maintain CID stability

### 4. Blob References

```typescript
export class BlobRef {
  constructor(
    public ref: CID,
    public mimeType: string,
    public size: number,
    original?: JsonBlobRef
  )

  static fromJsonRef(json: JsonBlobRef): BlobRef
  ipld(): TypedJsonBlobRef  // For IPLD encoding
  toJSON(): { $type: 'blob'; ref: { $link: string }; ... }
}
```

## String Format Validators Details

All format validators follow same pattern:
```typescript
export function formatName(path: string, value: string): ValidationResult {
  try {
    // Validate
    someValidator(value)
    return { success: true, value }
  } catch {
    return {
      success: false,
      error: new ValidationError(`${path} must be a formatName`)
    }
  }
}
```

**External dependencies used:**
- `iso-datestring-validator`: RFC 3339 datetime validation
- `multiformats/cid`: CID parsing and validation
- `@atproto/syntax`: isValidNsid, isValidTid, ensureValidDid, ensureValidHandle, ensureValidRecordKey, ensureValidAtUri
- `@atproto/common-web`: validateLanguage, graphemeLen, utf8Len

## XRPC Parameter Validation (validators/xrpc.ts)

**Special handling for parameters:**
- Parameters can only contain: primitives (bool, int, string), arrays of primitives, and no refs
- Object parameter schema validation similar to object validation
- Handles query string encoding constraints (size limits on serialized params)
- Defaults applied same way as in objects

## Key Validation Entry Points

From lexicons.ts:

```typescript
// Record validation (must have $type)
assertValidRecord(lexUri, value)

// Object/Record validation without type check
validate(lexUri, value)

// XRPC parameter validation
assertValidXrpcParams(lexUri, value)

// XRPC request body validation
assertValidXrpcInput(lexUri, value)

// XRPC response body validation
assertValidXrpcOutput(lexUri, value)

// Subscription message validation
assertValidXrpcMessage(lexUri, value)
```

All throw ValidationError on failure, return validated/transformed value on success.

## Patterns to Replicate in Elixir

1. **Runtime schema loading**: Parse JSON lexicons at startup, store in collection
2. **Discriminated unions**: Use `type` field for type discrimination
3. **Reference resolution**: Normalize URIs, handle implicit #main
4. **Validation pipeline**: Type → constraints → references → recursion
5. **Error messages with paths**: Track validation path for better errors
6. **Optimizations**:
   - Fast-path type checks before constraint checks
   - String length byte-count optimization for UTF-8
   - Lazy object cloning only when needed
7. **Defaults application**: Apply during validation, not storage
8. **Proper handling of nullable vs optional**: nullable allows null values, optional means field can be absent

## Dependencies Summary

```
@atproto/lexicon
├── zod@^3.23.8                 # Schema validation
├── multiformats@^9.9.0         # CID handling
├── iso-datestring-validator    # RFC 3339 datetime
├── @atproto/syntax             # NSID, TID, DID, handle validators
└── @atproto/common-web         # UTF-8 & grapheme length, language validation
```

No external validation libraries besides Zod - all custom validators in code.

## Example: Full Validation Flow

```typescript
// 1. Create Lexicons collection
const lexicons = new Lexicons([lexiconDoc])

// 2. Validate a record
const result = lexicons.validate('com.example.schema', {
  field1: 'value',
  field2: 123
})

// Internally:
// a) Normalize URI: com.example.schema → lex:com.example.schema#main
// b) Get definition from collection
// c) If record, validate internal object schema
// d) For each property:
//    - Check type matches
//    - Apply constraints (min/max/enum/const/format)
//    - Recursively validate nested objects/arrays
// e) Return { success: true, value: transformed }
//    or { success: false, error: ValidationError }
```
