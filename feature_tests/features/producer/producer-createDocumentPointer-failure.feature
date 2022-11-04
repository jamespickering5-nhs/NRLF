Feature: Failure Scenarios where producer unable to create a Document Pointer

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

  Scenario: Incorrect permissions
    Given Producer "CUTHBERT'S CLOSE CARE HOME" does not have permission to create Document Pointers for
      | snomed_code | description               |
      | 736253002   | Mental health crisis plan |
    When Producer "CUTHBERT'S CLOSE CARE HOME" creates a Document Reference from DOCUMENT template
      | property    | value                          |
      | identifier  | 1234567892                     |
      | type        | 887701000000100                |
      | custodian   | CUTHBERT'S CLOSE CARE HOME     |
      | subject     | 2742179658                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    Then the operation is unsuccessful
    And the response contains error message "Required permission to create a document pointer are missing"

  Scenario: Non existent producer
    Given Producer "CUTHBERT'S CLOSE CARE HOME4" does not exist in the system
    When Producer "CUTHBERT'S CLOSE CARE HOME4" creates a Document Reference from DOCUMENT template
      | property    | value                          |
      | identifier  | 1234567892                     |
      | type        | 887701000000100                |
      | custodian   | CUTHBERT'S CLOSE CARE HOME4    |
      | subject     | 2742179658                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    Then the operation is unsuccessful
    And the response contains error message "Custodian does not exist in the system"

  Scenario Outline: Missing/invalid required params
    Given Producer "AARON COURT MENTAL NH" has permission to create Document Pointers for
      | snomed_code | description               |
      | 736253002   | Mental health crisis plan |
    When Producer "AARON COURT MENTAL NH" creates a Document Reference from DOCUMENT template
      | property    | value                 |
      | identifier  | <identifier>          |
      | type        | <type>                |
      | custodian   | AARON COURT MENTAL NH |
      | subject     | <subject>             |
      | contentType | application/pdf       |
      | url         | <url>                 |
    Then the operation is unsuccessful
    And the response contains error message "<error_message>"

    Examples:
      | identifier | type      | subject           | url                            | error_message                                                                                         |
      | 1234567890 | 736253002 | 45646             | https://example.org/my-doc.pdf | DocumentReference validation failure - Invalid nhs_number - Not a valid NHS Number: 45646             |
      | 1234567890 | 736253002 |                   | https://example.org/my-doc.pdf | DocumentReference validation failure - Invalid subject                                                |
      | 1234567890 | 736253002 | Device/9278693472 | https://example.org/my-doc.pdf | DocumentReference validation failure - Invalid nhs_number - Not a valid NHS Number: Device/9278693472 |

  # | 1234567890 | 736253002 | 9278693472        |                                | DocumentReference validation failure - Blank value for key url                                                    |
  # | 1234567890   | 67          | 9278693472  | https://example.org/my-doc.pdf    | Code '67' from system 'http://snomed.info/sct' does not exist     |
  Scenario: Duplicate Document Pointer
    Given a Document Pointer exists in the system with the below values
      | property    | value                          |
      | identifier  | 1234567890                     |
      | type        | 736253002                      |
      | custodian   | AARON COURT MENTAL NH          |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    And Producer "AARON COURT MENTAL NH" has permission to create Document Pointers for
      | snomed_code | description               |
      | 736253002   | Mental health crisis plan |
    When Producer "AARON COURT MENTAL NH" creates a Document Reference from DOCUMENT template
      | property    | value                          |
      | identifier  | 1234567890                     |
      | type        | 736253002                      |
      | custodian   | AARON COURT MENTAL NH          |
      | subject     | 9278693472                     |
      | contentType | application/pdf                |
      | url         | https://example.org/my-doc.pdf |
    Then the operation is unsuccessful
    And the response contains error message "Condition check failed - Duplicate rejected"
