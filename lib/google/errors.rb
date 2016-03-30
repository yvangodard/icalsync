module Google
  class HTTPRequestFailed < StandardError; end
  class HTTPQuotaExceeded < StandardError; end
  class HTTPAuthorizationFailed < StandardError; end
  class HTTPNotFound < StandardError; end
  class HTTPTooManyRedirections < StandardError; end
  class UserRateLimitExceeded < StandardError; end
  class InvalidCalendar < StandardError; end
  class CalenarIDMissing < StandardError; end
end
