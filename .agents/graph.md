# OpenMRS Tajikistan — Shared Knowledge Graph (cross-module)
# Format: terse DSL. One fact per line. → = dependency/reference. # = comment.
# Scope: ONLY info that spans all 3 modules. Module-specific detail lives in
#   <module>/.agents/graph.md — see § MODULE MAP for pointers.
# Last updated: 2026-07-02

## § MODULE MAP
```
root/                               # Docker orchestration, SQL seeds, entrypoint.sh, openmrs.war
openmrs-module-mdrtb/               # Java OpenMRS module v1.3.6 (Maven) — backend REST resources + JSP UI
                                    #   detail: openmrs-module-mdrtb/.agents/graph.md
openmrs-module-mdrtb-web/           # Django 4.1.1 frontend — talks to OpenMRS via REST only, no direct DB
                                    #   detail: openmrs-module-mdrtb-web/.agents/graph.md
openmrs-mdrtb-etl-job/              # Python 3.12 ETL — migrates source DB → OpenMRS DB
                                    #   detail: openmrs-mdrtb-etl-job/.agents/graph.md + AGENTS.md
modules/                            # 15 pre-built .omod plugins; copied to ~/.OpenMRS/modules/ at startup
workshop/                           # scratch/workshop material (not deployed)
```

## § SYSTEM TOPOLOGY (infrastructure wiring)
```
mdrtb-web → openmrs:8080         # all patient data via REST (see web graph § OPENMRS REST API CALLS)
mdrtb-web → redis:6379           # Django session + metadata cache
openmrs   → mysql:3306           # host.docker.internal (MySQL runs on host OS, not in Docker)
openmrs   ← modules/*.omod       # 15 plugins loaded at container startup (incl. mdrtb-1.3.6)
etl-job   → mysql (source + target)  # direct SQLAlchemy, bypasses OpenMRS app layer
external  : QuaLIS LIMS at http://46.20.206.172:8083/QuaLIS/  # lab orders pushed from mdrtb-web
```

## § DOMAIN MODEL (OpenMRS DB — shared by Java module + ETL; web sees it via REST)
# Entity:Parent{key_fields} — audit cols (creator/date_created/voided/*) omitted for brevity
```
Person{person_id,gender,birthdate,dead,uuid}
Patient:Person{patient_id}
PersonName{person_name_id,person_id→Person,given_name,family_name,uuid}
PersonAddress{person_address_id,person_id→Person,address1..6,city_village,uuid}
PersonAttribute{person_attribute_id,person_id→Person,value,person_attribute_type_id,uuid}
PatientIdentifier{patient_identifier_id,patient_id→Patient,identifier,identifier_type,location_id,uuid}
PatientProgram{patient_program_id,patient_id→Patient,program_id→Program,date_enrolled,date_completed,outcome_concept_id,location_id,uuid}
Program{program_id,concept_id→Concept,outcomes_concept_id,name,uuid}
ProgramWorkflow{program_workflow_id,program_id→Program,concept_id→Concept,uuid}
ProgramWorkflowState{program_workflow_state_id,program_workflow_id→ProgramWorkflow,concept_id→Concept,initial,terminal,uuid}
Encounter{encounter_id,encounter_type→EncounterType,patient_id→Patient,provider_id→Provider,location_id→Location,form_id→Form,encounter_datetime,uuid}
EncounterType{encounter_type_id,name,uuid}
EncounterProvider{encounter_provider_id,encounter_id→Encounter,provider_id→Provider,encounter_role_id,uuid}
Obs{obs_id,person_id→Person,concept_id→Concept,encounter_id→Encounter,obs_datetime,obs_group_id→Obs,value_coded→Concept,value_numeric,value_text,value_datetime,value_boolean,uuid}
Orders{order_id,order_type_id→OrderType,concept_id→Concept,patient_id→Patient,encounter_id→Encounter,start_date,uuid}
DrugOrder:Orders{drug_inventory_id→Drug,dose,units,frequency}
Drug{drug_id,concept_id→Concept,name,uuid}
Concept{concept_id,datatype_id→ConceptDatatype,class_id→ConceptClass,uuid}
ConceptName{concept_name_id,concept_id→Concept,name,locale,concept_name_type,uuid}
ConceptAnswer{concept_answer_id,concept_id→Concept,answer_concept→Concept,sort_weight,uuid}
ConceptSet{concept_set_id,concept_id→Concept,concept_set→Concept,uuid}
ConceptNumeric{concept_id→Concept,hi_normal,low_normal,units}
Location{location_id,name,level,parent_location→Location,uuid}
Provider{provider_id,person_id→Person,name,identifier,uuid}
Users{user_id,username,person_id→Person,uuid}
Role{role,uuid} [M:M]→Users [M:M]→Privilege
Privilege{privilege,uuid}
Form{form_id,name,encounter_type→EncounterType,uuid}
Cohort{cohort_id,name,uuid} [M:M]→Patient
LabTestType{test_type_id,name,short_name,test_group,reference_concept_id→Concept,uuid}   # CommonLab module
LabTestAttributeType{test_attribute_type_id,test_type_id→LabTestType,name,datatype,uuid}
AddressHierarchyLevel{level_id,name}
AddressHierarchyEntry{id,name,level_id→AddressHierarchyLevel,parent_id→AddressHierarchyEntry}
GlobalProperty{property,property_value,uuid}
```

## § ENUMS (shared vocabulary)
```
TbClassification:     MONO_RESISTANT_TB|POLY_RESISTANT_TB|MDR_TB|XDR_TB|RIF_RESISTANT_TB|PRE_XDR_TB
TreatmentState:       NOT_ON_TREATMENT|ON_TREATMENT
SampleStatus:         COLLECTED|ACCEPTED|PROCESSED|REJECTED
Locale:               en|ru|tj|en_GB    # tj = Tajik (primary target)
Programs:             DOTS=e80fec43-f2b5-45b0-aec1-eaf74be26ff9 | MDR_TB=34198d48-0370-102d-b0e3-001ec94a0cc1
```

## § ENCOUNTER TYPES (UUIDs — defined in Java module, mirrored in web resources/enums/encounterType.py)
```
TB03                 = 0479de9f-e5ea-45d7-b7a8-cda85bc8bc3d  # DOTS intake form
TB03U_MDR            = d25e1cb2-ef3b-40bb-a8d8-6010d1d431c0
TB03U_XDR            = e7b10822-b5de-468b-9924-600c9fc4296d
FORM_89              = 44539237-5401-424c-84d7-6694436ed2a0
ADVERSE_EVENT        = bfa6ef9f-a8fe-4bd3-ab8c-ec6bbfc85457
LAB_RESULT           = d8194104-04af-455f-a623-4d9302f38ea3
SPECIMEN_COLLECTION  = 327e85ce-0370-102d-b0e3-001ec94a0cc1
TRANSFER_IN          = 1eb25540-552c-4641-9913-c7545fe0777f
TRANSFER_OUT         = e27d997c-3f93-460b-ad84-77db79e2661e
RESISTANCE_DURING_TX = a3ca01a4-6ff8-4909-b483-1ceb0f354d40
PV_REGIMEN           = 99f4f9d8-b23f-4406-bb03-03e1237634aa
```

## § KEY CONCEPT UUIDS (stored as Obs.concept_id or Obs.value_coded — shared by all modules)
```
# Treatment outcomes
CURED                   = 31b6bb34-0370-102d-b0e3-001ec94a0cc1
TREATMENT_COMPLETE      = 31b69906-0370-102d-b0e3-001ec94a0cc1
TREATMENT_FAILED        = 31b0e4ac-0370-102d-b0e3-001ec94a0cc1
DEFAULTED               = 31b60f40-0370-102d-b0e3-001ec94a0cc1
DIED                    = 31b6b7d8-0370-102d-b0e3-001ec94a0cc1
LOST_TO_FOLLOWUP        = 31c7bbdc-0370-102d-b0e3-001ec94a0cc1
PATIENT_TRANSFERRED_OUT = 31b6b986-0370-102d-b0e3-001ec94a0cc1
TREATMENT_OUTCOME_DATE  = 5060d5ce-df8e-4090-b09e-62e40a29201a
# TB classification
RESISTANCE_TYPE         = 3f5a6930-5ead-4880-80ce-6ab79f4f6cb1
RR_TB                   = d78087db-6146-40d4-9dff-5b249e1b4eca
PRE_XDR_TB              = 9e263164-586f-47a1-824b-a1d205cc51fe
MDR_TB_PROGRAM_CONCEPT  = 31bd79ec-0370-102d-b0e3-001ec94a0cc1
# First-line drugs
ISONIAZID    = 31afed04-0370-102d-b0e3-001ec94a0cc1
RIFAMPICIN   = 31b09a60-0370-102d-b0e3-001ec94a0cc1
ETHAMBUTOL   = 31b08840-0370-102d-b0e3-001ec94a0cc1
PYRAZINAMIDE = b877ac5a-7e03-4c38-bab5-6afe5ac76a74
STREPTOMYCIN = 18876a12-3a06-450c-af3c-aaa774e902b6
# Second-line drugs
MOXIFLOXACIN = 31b1e398-0370-102d-b0e3-001ec94a0cc1
LEVOFLOXACIN = 31b0907e-0370-102d-b0e3-001ec94a0cc1
OFLOXACIN    = 31b4a9b6-0370-102d-b0e3-001ec94a0cc1
KANAMYCIN    = 31b4a8e4-0370-102d-b0e3-001ec94a0cc1
CAPREOMYCIN  = 31b4a3ee-0370-102d-b0e3-001ec94a0cc1
AMIKACIN     = 31b49fca-0370-102d-b0e3-001ec94a0cc1
CYCLOSERINE  = 31b4a592-0370-102d-b0e3-001ec94a0cc1
ETHIONAMIDE  = 31b4a664-0370-102d-b0e3-001ec94a0cc1
LINEZOLID    = b4d9a4cc-a6cd-431f-8915-5dd96e7cf678
BEDAQUILINE  = a60a046e-0739-4bd8-83b6-fe86e4771b48
DELAMANID    = e1236682-8451-4c75-b4ba-44457d1ebf43
CLOFAZIMINE  = 31b4a4c0-0370-102d-b0e3-001ec94a0cc1
# Lab test constructs (obs group anchors)
CULTURE_CONSTRUCT  = 31bf10e0-0370-102d-b0e3-001ec94a0cc1
CULTURE_RESULT     = 31bf0f32-0370-102d-b0e3-001ec94a0cc1
SMEAR_CONSTRUCT    = 31bf1518-0370-102d-b0e3-001ec94a0cc1
SMEAR_RESULT       = 31bf1446-0370-102d-b0e3-001ec94a0cc1
DST_CONSTRUCT      = 31bf09b0-0370-102d-b0e3-001ec94a0cc1
DST_RESULT         = 31befcf4-0370-102d-b0e3-001ec94a0cc1
XPERT_CONSTRUCT    = 6a6be4e0-9a56-4376-a8b3-9b6a9ec2d9bf
MTB_RESULT         = 731bdb67-f216-477f-85c2-8af92d999121
RIFAMPICIN_RESIST  = 12235c33-e627-4636-8b85-8643fadc622e
HAIN_CONSTRUCT     = d587d8cb-6f41-466d-9426-22c712783cd5
HAIN2_CONSTRUCT    = 3cbafe53-8630-446e-9905-b83c5c6fd04b
ISONIAZID_RESIST   = 9446085c-86ae-4e06-b571-f8a88217b472
# Lab result values
POSITIVE    = 31b0141e-0370-102d-b0e3-001ec94a0cc1
NEGATIVE    = 31aff3c6-0370-102d-b0e3-001ec94a0cc1
DETECTED    = b24aeae2-6234-4e5d-95ec-97d03545a425
NOT_DETECTED= 2710ad98-8f02-40a7-b0d4-8d0c6668dfa9
CONTAMINATED= 31b4a09c-0370-102d-b0e3-001ec94a0cc1
# Treatment regimens
SHORT_MDR_REGIMEN                    = 30eece8f-ed94-4241-b89c-2449bede927e
STANDARD_MDR_REGIMEN                 = c44661eb-3641-45c1-9fb2-f7ca87adf617
INDIVIDUAL_WITH_BEDAQUILINE          = c2358f1f-1d96-497a-849a-9f678b72c657
INDIVIDUAL_WITH_DELAMANID            = 7531b943-418c-4234-9f95-d18d1fccaa36
INDIVIDUAL_WITH_BEDAQUILINE_DELAMANID= dcf5702f-b9f7-4e0c-a502-884c6d5bdc5c
OTHER_MDRTB_REGIMEN                  = 79838176-04c9-419e-bf75-3658c220ff34
# Tajikistan custom
MDR_TREATMENT_START_DATE = 8abe1e01-f167-4618-9f8e-e21ac3dcdf14
AGE_AT_MDR_REGISTRATION  = b8135923-db22-4db5-b8c8-7d31a02b4cd3
DATE_OF_MDR_CONFIRMATION = c029cb31-867b-4e2e-b75d-e72ee584524a
MONTH_OF_TREATMENT       = 0977d2a9-84a4-40dc-95b3-30d7c709cd92
FUNDING_SOURCE           = e56514ed-1b3b-4d2e-89f1-564fd6265ebe
ADVERSE_EVENT            = 7047f880-b929-42fc-81f7-b9dbba2d1b15
```

## § IDENTIFIER TYPES (UUIDs — mirrored in web resources/enums/constants.py)
```
OPENMRS_IDENTIFIER = 8d793bee-c2cc-11de-8d13-0010c6dffd0f
SUSPECT_IDENTIFIER = f3ea5e6d-8b40-4e34-b97d-56577480bfe9
DOTS_IDENTIFIER    = 8d79403a-c2cc-11de-8d13-0010c6dffd0f
MDR_IDENTIFIER     = 5c4c9795-2a7a-4757-8585-fba3a7cafa90
```

## § DOCKER / DEPLOYMENT CONFIG (root .env-example)
```
OPENMRS_DB_HOST       default: host.docker.internal   # MySQL on host OS
OPENMRS_DB_PORT       default: 3306
OPENMRS_DB_NAME       default: openmrs
OPENMRS_DB_USER       default: openmrs
OPENMRS_DB_PASSWORD   default: openmrs
OPENMRS_HOST_PORT     default: 8080
REDIS_HOST            default: redis
REDIS_PORT            default: 6379
MDRTB_WEB_HOST_PORT   default: 8000
```

## § STARTUP FLOW
```
docker-compose up →
  1. redis:7-alpine    (health: redis-cli ping)
  2. openmrs           (depends_on: redis healthy)
       entrypoint.sh:
         a. mkdir ~/.OpenMRS/modules/
         b. cp modules/*.omod ~/.OpenMRS/modules/
         c. envsubst < openmrs-runtime.properties.template > ~/.OpenMRS/openmrs-runtime.properties
         d. wait_for_mysql host.docker.internal:3306
         e. if DB empty: mysql < openmrs_schema.sql && mysql < openmrs_seed.sql
         f. catalina.sh run   # Tomcat 9 + JDK11, serves openmrs.war
  3. mdrtb-web         (depends_on: openmrs, redis)
       Dockerfile: gunicorn --workers 2 settings.wsgi:application

Health checks:
  redis:   redis-cli ping → PONG
  openmrs: HTTP GET /openmrs → 200|302|401 acceptable
```

## § LOCALIZATION (overview — file locations in each module's graph.md)
```
Languages: en | ru | tj | en_GB    # tj = Tajik (primary target), default locale = ru
Web:  session locale from OpenMRS userProperties.locale; switch via GET /changelocale/<locale>
Java: messages_{tj,ru,fr,id_ID}.properties in api+omod resources
```

## § MODULES DEPLOYED AT STARTUP (modules/*.omod)
```
addresshierarchy-2.21.0      # geographic hierarchy UI
calculation-2.0.0            # calculation engine
cohort-3.7.3                 # cohort management
htmlformentry-6.1.0          # HTML form framework
htmlwidgets-2.0.1            # HTML UI components
idgen-5.0.4                  # patient ID generation
legacyui-2.1.0               # JSP support
mdrtb-1.3.6                  # this project's Java module (MDR-TB)
metadatamapping-1.7.0        # metadata mapping
reporting-2.1.0              # reporting framework
reportingcompatibility-2.10.0
reportingrest-2.0.0          # REST reporting API
serialization.xstream-0.3.0
webservices.rest-2.51.0      # REST API framework
```
