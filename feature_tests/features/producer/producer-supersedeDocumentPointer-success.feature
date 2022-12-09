Feature: Success Scenarios where producer unable to supersede Document Pointers

  Background:
    Given template DOCUMENT
      """
      {
        "resourceType": "DocumentReference",
        "id": "$identifier",
        "custodian": {
          "identifier": {
            "system": "https://fhir.nhs.uk/Id/accredited-system-id",
            "value": "$custodian"
          }
        },
        "subject": {
          "identifier": {
            "system": "https://fhir.nhs.uk/Id/nhs-number",
            "value": "$subject"
          }
        },
        "type": {
          "coding": [
            {
              "system": "https://snomed.info/ict",
              "code": "$type"
            }
          ]
        },
        "content": [
          {
            "attachment": {
              "contentType": "$contentType",
              "url": "$url"
            }
          }
        ],
        "status": "current",
        "relatesTo": [
          {
            "code": "replaces",
            "target": {
              "type": "DocumentReference",
              "identifier": {
                "value": "$target"
              }
            }
          }
        ]
      }
      """

  Scenario: Supersede multiple Document Pointers
    Given Producer "Aaron Court Mental Health NH" (Organisation ID "8FW23") is requesting to create Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" (ID "z00z-y11y-x22x") for document types
      | system                  | value     |
      | https://snomed.info/ict | 736253002 |
    And Producer "Aaron Court Mental Health NH" has authorisation headers for application "DataShare" (ID "z00z-y11y-x22x")
    And a Document Pointer exists in the system with the below values for DOCUMENT template
      | property    | value                          |
      | identifier  | 8FW23\|1234567890              |
      | type        | 736253002                      |
      | custodian   | 8FW23                          |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    And a Document Pointer exists in the system with the below values for DOCUMENT template
      | property    | value                          |
      | identifier  | 8FW23\|1234567891              |
      | type        | 736253002                      |
      | custodian   | 8FW23                          |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    When Producer "Aaron Court Mental Health NH" creates a Document Reference from DOCUMENT template
      | property    | value                          |
      | identifier  | 8FW23\|1234567892              |
      | target      | 8FW23\|1234567890              |
      | target      | 8FW23\|1234567891              |
      | type        | 736253002                      |
      | custodian   | 8FW23                          |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    Then the operation is successful
    And Document Pointer "8FW23|1234567892" exists
      | property    | value                              |
      | id          | 8FW23\|1234567892                  |
      | nhs_number  | 9278693472                         |
      | producer_id | 8FW23                              |
      | type        | https://snomed.info/ict\|736253002 |
      | source      | NRLF                               |
      | version     | 1                                  |
      | updated_on  | NULL                               |
      | document    | <document>                         |
      | created_on  | <timestamp>                        |
    And Document Pointer "8FW23|1234567890" does not exist
    And Document Pointer "8FW23|1234567891" does not exist
