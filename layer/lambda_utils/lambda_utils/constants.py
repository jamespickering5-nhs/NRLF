from logging import ERROR, INFO


class HttpStatusCodes:
    OK = 200
    BAD_REQUEST = 400
    INTERNAL_SERVER_ERROR = 500


class LoggingOutcomes:
    SUCCESS = "SUCCESS"
    FAILURE = "FAILURE"
    ERROR = "ERROR"


class LoggingConstants:
    TO_MILLISECONDS = 1000
    JSON_INDENT = 2
    RESERVED_FIELDS = ["self", "logger", "context", "dependencies", "event"]


class LogLevel:
    INFO = INFO
    ERROR = ERROR


class ApiRequestLevel:
    USER_RESTRICTED = "user_restricted"
    APP_RESTRICTED = "app_restricted"


CLIENT_RP_DETAILS = "nhsd-client-rp-details"
NULL = "null"
