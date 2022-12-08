Feature: Success scenarios where producer is able to delete a Document Pointer

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

  Scenario: Delete an existing current Document Pointer
    Given Producer "Aaron Court Mental Health NH" is requesting to delete Document Pointers
    And Producer "Aaron Court Mental Health NH" is registered in the system for application "DataShare" for document types
      | system                  | value     |
      | https://snomed.info/ict | 736253002 |
    And Producer "Aaron Court Mental Health NH" has authorisation headers for application "DataShare"
    And a Document Pointer exists in the system with the below values for DOCUMENT template
      | property    | value                          |
      | identifier  | 1234567890                     |
      | type        | 736253002                      |
      | custodian   | Aaron Court Mental Health NH   |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    When Producer "Aaron Court Mental Health NH" deletes an existing Document Reference "Aaron Court Mental Health NH|1234567890"
    Then the operation is successful
    And the response contains the message "Resource removed"
