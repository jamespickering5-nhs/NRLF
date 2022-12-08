Feature: Failure scenarios where producer is unable to read a Document Pointer

  Background:
    Given template DOCUMENT
      """
      {
        "resourceType": "DocumentReference",
        "id": "$custodian|$identifier",
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
        "status": "current"
      }
      """

  Scenario: Producer permissions do not match the Document Pointer type
    Given Producer "Aaron Court Mental Health NH" is requesting to read Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" for document types
      | system                  | value     |
      | https://snomed.info/ict | 734163000 |
    And Producer "Aaron Court Mental Health NH" has authorisation headers for application "DataShare"
    And a Document Pointer exists in the system with the below values for DOCUMENT template
      | property    | value                          |
      | identifier  | 1234567890                     |
      | type        | 736253002                      |
      | custodian   | Aaron Court Mental Health NH   |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    When Producer "Aaron Court Mental Health NH" reads an existing Document Reference "Aaron Court Mental Health NH|1234567890"
    Then the operation is unsuccessful
    And the response contains error message "Item could not be found"

  Scenario: Request comes from a Producer whose ID does not match the Document Pointer's producer ID
    Given Producer "Aaron Court Mental Health NH" is requesting to read Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" for document types
      | system                  | value     |
      | https://snomed.info/ict | 734163000 |
    And Producer "Aaron Court Mental Health NH" has authorisation headers for application "DataShare"
    And a Document Pointer exists in the system with the below values for DOCUMENT template
      | property    | value                          |
      | identifier  | 1234567890                     |
      | type        | 736253002                      |
      | custodian   | ABUNDANT LIFE CARE LIMITED     |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    When Producer "Aaron Court Mental Health NH" reads an existing Document Reference "ABUNDANT LIFE CARE LIMITED|1234567890"
    Then the operation is unsuccessful
    And the response contains error message "Required permissions to read a document pointer are missing"

  Scenario: The Document Pointer does not exist
    Given Producer "Aaron Court Mental Health NH" is requesting to read Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" for document types
      | system                  | value     |
      | https://snomed.info/ict | 734163000 |
    And Producer "Aaron Court Mental Health NH" has authorisation headers for application "DataShare"
    When Producer "Aaron Court Mental Health NH" reads an existing Document Reference "Aaron Court Mental Health NH|1234567890"
    Then the operation is unsuccessful
    And the response contains error message "Item could not be found"
