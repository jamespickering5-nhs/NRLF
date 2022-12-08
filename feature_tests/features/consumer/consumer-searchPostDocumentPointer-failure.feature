Feature: Basic Success Scenarios where consumer is able to search by POST for Document Pointers

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

  Scenario: Search by POST fails to return a bundle when extra parameters are found
    Given Consumer "Yorkshire Ambulance Service" is requesting to search by POST for Document Pointers
    And Consumer "Yorkshire Ambulance Service" is registered in the system for application "DataShare" for document types
      | system                  | value     |
      | https://snomed.info/ict | 736253002 |
    And Consumer "Yorkshire Ambulance Service" has authorisation headers for application "DataShare"
    And a Document Pointer exists in the system with the below values for DOCUMENT template
      | property    | value                          |
      | identifier  | 1114567890                     |
      | type        | 736253002                      |
      | custodian   | AARON COURT MENTAL NH          |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    When Consumer "Yorkshire Ambulance Service" searches by POST for Document References with body parameters:
      | property | value                                         |
      | subject  | https://fhir.nhs.uk/Id/nhs-number\|9278693472 |
      | extra    | unwanted field                                |
    Then the operation is unsuccessful
    And the response contains error message "Unexpected query parameters: extra"
