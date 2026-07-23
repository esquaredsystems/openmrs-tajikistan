# .agents/instructions.md — How to Use the Knowledge Graphs

## Purpose
This project keeps a **layered, token-efficient index** of the codebase so agents
can find where things live without loading 3,000-line files into context.

There are FOUR `.agents` directories:

| Location | Scope |
|---|---|
| `.agents/` (root, this dir) | Cross-cutting info only: system topology, shared domain model, shared UUIDs (concepts, encounter types, identifiers), Docker/startup flow, deployed plugins |
| `openmrs-module-mdrtb/.agents/` | Java OpenMRS module: layout, Maven deps, JSP views, REST resources exposed, global properties |
| `openmrs-module-mdrtb-web/.agents/` | Django frontend: URL routes, auth flow, REST calls consumed, utility call graph, cache keys, settings |
| `openmrs-mdrtb-etl-job/.agents/` | ETL job: pipeline flow + `AGENTS.md` with conventions, do-not-touch rules, and agent workflow |

Workflow: **root graph.md first** (topology + shared facts) → jump to the module
graph.md for the module you're working in → identify file path + symbol → read
only that file/function. Do not read whole files to find a UUID or route.

## Routing Rule
| You are working on… | Read |
|---|---|
| Docker, startup, infra, cross-module data flow | `.agents/graph.md` |
| A concept/encounter-type/identifier UUID | `.agents/graph.md` (§ KEY CONCEPT UUIDS etc.) |
| Django views, URLs, auth, sessions, caching, UI | `openmrs-module-mdrtb-web/.agents/graph.md` |
| Java module, JSPs, Maven, REST resource classes, global properties | `openmrs-module-mdrtb/.agents/graph.md` |
| Data migration, staging tables, extract/load | `openmrs-mdrtb-etl-job/.agents/AGENTS.md` + `graph.md` |

## Notation Legend (applies to all graph.md files)
```
→              dependency, foreign-key reference, or call direction
:              inheritance / extends (Entity:Parent)
{f1,f2}        fields / columns (audit columns omitted)
[M:M]→X       many-to-many relation to X
#              inline comment / clarification
§              section header
GET/POST path  Django URL route with HTTP methods
ru / pu / fu / clu / mu / lu   Django utility module aliases used in views.py
```

## Maintenance Rule

**The graphs MUST be updated after every major code change.** Update the file
that owns the fact — never duplicate a fact in two graphs:

| Change type | File → section |
|---|---|
| New or renamed Django URL / view | web `.agents/graph.md` § REST ROUTES |
| New utility dependency in views.py | web `.agents/graph.md` § UTILITY CALL GRAPH |
| Django config / cache / auth change | web `.agents/graph.md` (relevant §) |
| New Java REST resource / JSP / Maven dep | mdrtb `.agents/graph.md` (relevant §) |
| New mdrtb.* global property | mdrtb `.agents/graph.md` § GLOBAL PROPERTIES |
| New ETL entity group / order change | etl `.agents/graph.md` § ETL PIPELINE |
| ETL convention or safety rule | etl `.agents/AGENTS.md` |
| New entity field or DB table / migration | root `.agents/graph.md` § DOMAIN MODEL |
| New concept / encounter type / identifier UUID | root `.agents/graph.md` (relevant §) |
| Config key added (Docker/env) | root `.agents/graph.md` § DOCKER / DEPLOYMENT CONFIG |
| New .omod module deployed | root `.agents/graph.md` § MODULES DEPLOYED |
| Startup / compose change | root `.agents/graph.md` § STARTUP FLOW |

Update the `# Last updated:` timestamp at the top of the edited graph.md.

## What the Graphs Do NOT Contain
- Full concept lists (only the ~60 most-referenced UUIDs; full set in
  `openmrs-module-mdrtb-web/resources/enums/mdrtbConcepts.py`)
- Complete privilege list (299 entries; read
  `openmrs-module-mdrtb-web/resources/enums/privileges.py`)
- JSP/template structure (read `openmrs-module-mdrtb/omod/src/main/webapp/`)
- ETL transformation logic (read `openmrs-mdrtb-etl-job/etl/*.py` directly)
- SQL schema details (read `openmrs_schema.sql` or
  `openmrs-mdrtb-etl-job/models/schema_models.py`)
