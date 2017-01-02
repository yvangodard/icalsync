require 'time'
require 'json'

module Google

  #
  # Represents a Google Event.
  #
  # === Attributes
  #
  # * +id+ - The google assigned id of the event (nil until saved). Read Write.
  # * +status+ - The status of the event (confirmed, tentative or cancelled). Read Write.
  # * +title+ - The title of the event. Read Write.
  # * +description+ - The content of the event. Read Write.
  # * +location+ - The location of the event. Read Write.
  # * +start_time+ - The start time of the event (Time object, defaults to now). Read Write.
  # * +end_time+ - The end time of the event (Time object, defaults to one hour from now).  Read Write.
  # * +recurrence+ - A hash containing recurrence info for repeating events. Read write.
  # * +calendar+ - What calendar the event belongs to. Read Write.
  # * +all_day + - Does the event run all day. Read Write.
  # * +quickadd+ - A string that Google parses when setting up a new event.  If set and then saved it will take priority over any attributes you have set. Read Write.
  # * +reminders+ - A hash containing reminders. Read Write.
  # * +attendees+ - An array of hashes containing information about attendees. Read Write
  # * +transparency+ - Does the event 'block out space' on the calendar.  Valid values are true, false or 'transparent', 'opaque'. Read Write.
  # * +duration+ - The duration of the event in seconds. Read only.
  # * +html_link+ - An absolute link to this event in the Google Calendar Web UI. Read only.
  # * +raw+ - The full google json representation of the event. Read only.
  # * +visibility+ - The visibility of the event (*'default'*, 'public', 'private', 'confidential'). Read Write.
  #
  class Event
    attr_reader :raw, :html_link
    attr_accessor :id, :status, :title, :location, :calendar,  :quickadd, :transparency, :attendees, :description, :reminders, :recurrence, :visibility

    #
    # Create a new event, and optionally set it's attributes.
    #
    # ==== Example
    #
    # event = Google::Event.new
    # event.calendar = AnInstanceOfGoogleCalendaer
    # event.id = "0123456789abcdefghijklmopqrstuv"
    # event.start_time = Time.now
    # event.end_time = Time.now + (60 * 60)
    # event.recurrence = {'freq' => 'monthly'}
    # event.title = "Go Swimming"
    # event.description = "The polar bear plunge"
    # event.location = "In the arctic ocean"
    # event.transparency = "opaque"
    # event.visibility = "public"
    # event.reminders = {'useDefault'  => false, 'overrides' => ['minutes' => 10, 'method' => "popup"]}
    # event.attendees = [
    #                     {'email' => 'some.a.one@gmail.com', 'displayName' => 'Some A One', 'responseStatus' => 'tentative'},
    #                     {'email' => 'some.b.one@gmail.com', 'displayName' => 'Some B One', 'responseStatus' => 'tentative'}
    #                   ]
    #
    def initialize(params = {})
      [:id, :status, :raw, :html_link, :title, :location, :calendar, :quickadd, :attendees, :description, :reminders, :recurrence, :start_time, :end_time].each do |attribute|
        instance_variable_set("@#{attribute}", params[attribute])
      end

      @new_event = true

      self.visibility   = params[:visibility]
      self.transparency = params[:transparency]
    end

    #
    # Sets the id of the Event.
    #
    def id=(id)
      @id = Event.parse_id(id) unless id.nil?
    end

    def new_event=(bool)
      @new_event = bool
    end

    def status=(status)
      @status = Event.parse_status(status) unless status.nil?
    end

    #
    # Sets the start time of the Event.  Must be a Time object or a parse-able string representation of a time.
    #
    def start_time=(time)
      #@start_time = Event.parse_time(time)
      raise "start_time must be Time" unless time.is_a?(Time)
      @start_time = time.dup.utc
    end

    #
    # Get the start_time of the event.
    #
    # If no time is set (i.e. new event) it defaults to the current time.
    #
    def start_time
      #@start_time ||= Time.now.utc
      #(@start_time.is_a? String) ? @start_time : @start_time.xmlschema
      @start_time
    end

    #
    # Get the end_time of the event.
    #
    # If no time is set (i.e. new event) it defaults to one hour in the future.
    #
    def end_time
      @end_time ||= Time.now.utc + (60 * 60) # seconds * min
      #(@end_time.is_a? String) ? @end_time : @end_time.xmlschema
    end

    #
    # Sets the end time of the Event.  Must be a Time object or a parse-able string representation of a time.
    #
    #def end_time=(time)
      #@end_time = Event.parse_time(time)
      #raise ArgumentError, "End Time must be either Time or String" unless (time.is_a?(String) || time.is_a?(Time))
      #@end_time = (time.is_a? String) ? Time.parse(time) : time.dup.utc
    #end
    def end_time=(time)
      raise "end_time must be Time" unless time.is_a?(Time)
      @end_time = time.dup.utc
    end

    #
    # Returns whether the Event is an all-day event, based on whether the event starts at the beginning and ends at the end of the day.
    #
    def all_day?
      time = start_time.dup
      time.localtime
      # 3600 for dst
      (duration % (24 * 60 * 60)).between?(-3600, 3600) && time == Time.local(time.year,time.month,time.day)
    end

    #
    # Makes an event all day, by setting it's start time to the passed in time and it's end time 24 hours later.
    # Note: this will clobber both the start and end times currently set.
    #
    #def all_day(time, end_time=nil)
      #if time.class == String
        #time = Time.parse(time)
      #end
      #if end_time.class == String
        #end_time = Time.parse(end_time)
      #end
      #@start_time = time.strftime("%Y-%m-%d")
      #@end_time = end_time ? end_time.strftime("%Y-%m-%d"): (time + 24*60*60).strftime("%Y-%m-%d")
    #end

    #
    # Duration of the event in seconds
    #
    def duration
      end_time - start_time
    end

    #
    # Stores reminders for this event. Multiple reminders are allowed.
    #
    # Examples
    #
    # event = cal.create_event do |e|
    #   e.title = 'Some Event'
    #   e.start_time = Time.now + (60 * 10)
    #   e.end_time = Time.now + (60 * 60) # seconds * min
    #   e.reminders = { 'useDefault'  => false, 'overrides' => [{method: 'email', minutes: 4}, {method: 'popup', minutes: 60}, {method: 'sms', minutes: 30}]}
    # end
    #
    # event = Event.new :start_time => "2012-03-31", :end_time => "2012-04-03", :reminders => { 'useDefault'  => false, 'overrides' => [{'minutes' => 10, 'method' => "popup"}]}
    #
    def reminders
      @reminders ||= {}
    end

    #
    # Stores recurrence rules for repeating events.
    #
    # Allowed contents:
    # :freq => frequence information ("daily", "weekly", "monthly", "yearly")   REQUIRED
    # :count => how many times the repeating event should occur                 OPTIONAL
    # :until => Time class, until when the event should occur                   OPTIONAL
    # :interval => how often should the event occur (every "2" weeks, ...)      OPTIONAL
    # :byday => if frequence is "weekly", contains ordered (starting with       OPTIONAL
    #             Sunday)comma separated abbreviations of days the event
    #             should occur on ("su,mo,th")
    #           if frequence is "monthly", can specify which day of month
    #             the event should occur on ("2mo" - second Monday, "-1th" - last Thursday,
    #             allowed indices are 1,2,3,4,-1)
    #
    # Note: The hash should not contain :count and :until keys simultaneously.
    #
    # ===== Example
    # event = cal.create_event do |e|
    #   e.title = 'Work-day Event'
    #   e.start_time = Time.now
    #   e.end_time = Time.now + (60 * 60) # seconds * min
    #   e.recurrence = {freq: "weekly", byday: "mo,tu,we,th,fr"}
    # end
    #
    def recurrence
      @recurrence ||= {}
    end

    #
    # Utility method that simplifies setting the transparency of an event.
    # You can pass true or false.  Defaults to transparent.
    #
    def transparency=(val)
      if val == false || val.to_s.downcase == 'opaque'
        @transparency = 'opaque'
      else
        @transparency = 'transparent'
      end
    end

    #
    # Returns true if the event is transparent otherwise returns false.
    # Transparent events do not block time on a calendar.
    #
    def transparent?
      @transparency == "transparent"
    end

    #
    # Returns true if the event is opaque otherwise returns false.
    # Opaque events block time on a calendar.
    #
    def opaque?
      @transparency == "opaque"
    end

    #
    # Sets the visibility of the Event.
    #
    def visibility=(val)
      if val
        @visibility = Event.parse_visibility(val)
      else
        @visibility = "default"      
      end
    end

    #
    # Convenience method used to build an array of events from a Google feed.
    #
    def self.build_from_google_feed(response, calendar)
      events = response['items'] ? response['items'] : [response]
      events.collect {|e| new_from_feed(e, calendar)}.flatten
    end

    ##
    ## Google JSON representation of an event object.
    ##
    #def to_json
      #json = "{\n"
      #json += "\"id\": #{id.to_json},\n" if id
      #json += "\"status\": #{status.to_json},\n" if status
      #json += "\"summary\": #{title.to_json},\n" if title
      #json += "\"visibility\": #{visibility.to_json},\n" if visibility
      #json += "\"description\": #{description.to_json},\n" if description
      #json += "\"location\": #{location.to_json},\n" if location
      #json += "\"start\": {\n"
      #json += "\t\"dateTime\": \"#{start_time}\"\n"
      #json += " #{timezone_needed? ? local_timezone_json : ''}"
      #json += "}\n,"
      #json += "\"end\": {\n"
      #json += "\t\"dateTime\": \"#{end_time}\"\n"
      #json += "#{timezone_needed? ? local_timezone_json : ''}"
      #json += "},\n"
      #json += "#{recurrence_json}"
      #json += "#{attendees_json}"
      #json += "\"reminders\": {\n"
        #json += "#{reminders_json}"
      #json += " }\n"
    #json += "}\n"
    #end
    #
    # Google JSON representation of an event object.
    #
    def to_json
      json = "{\n"
      json += "\"id\": #{id.to_json},\n" if id
      json += "\"status\": #{status.to_json},\n" if status
      json += "\"summary\": #{title.to_json},\n" if title
      json += "\"visibility\": #{visibility.to_json},\n" if visibility
      json += "\"description\": #{description.to_json},\n" if description
      json += "\"location\": #{location.to_json},\n" if location
      json += "#{dates_json}"
      json += "#{recurrence_json}"
      json += "#{attendees_json}"
      json += "\"reminders\": {\n"
      json += "#{reminders_json}"
      json += " }\n"
      json += "}\n"
    end

    def dates_json
      date_type = all_day? ? 'date' : 'dateTime'
      _start = all_day? ? start_time.getlocal.strftime('%Y-%m-%d') : start_time.xmlschema
      _end = all_day? ? end_time.getlocal.strftime('%Y-%m-%d') : end_time.xmlschema
      json = "\"start\": {\n"
      json += "\t\"#{date_type}\": \"#{_start}\"\n"
      json += " #{timezone_needed? ? local_timezone_json : ''}"
      json += "}\n,"
      json += "\"end\": {\n"
      json += "\t\"#{date_type}\": \"#{_end}\"\n"
      json += "#{timezone_needed? ? local_timezone_json : ''}"
      json += "},\n"
    end

    #
    # JSON representation of attendees
    #
    def attendees_json
      return unless @attendees
      #attendees = @attendees.map do |attendee|
        #"{
          #\"displayName\": \"{attendee['displayName']}\",
          #\"email\": \"{attendee['email']}\",
          #\"responseStatus\": \"{attendee['responseStatus']}\"
        #}"
      #end.join(",\n")

      attendees = @attendees.map do |attendee|
        json = "{"
        json += " \"displayName\": #{attendee['displayName'].to_json}" if attendee['displayName']
        json += " ,\"email\": #{attendee['email'].to_json}" if attendee['email']
        json += " ,\"responseStatus\": #{attendee['responseStatus'].to_json}" if attendee['responseStatus']
        json += " }"
        json
      end.join(",\n")

      "\"attendees\": [\n#{attendees}],"
    end

    #
    # JSON representation of a reminder
    #
    def reminders_json
      if reminders && reminders.is_a?(Hash) && reminders['overrides']
        overrides = reminders['overrides'].map do |reminder|
          "{
            \"method\": \"#{reminder['method']}\",
            \"minutes\": #{reminder['minutes']}
          }"
        end.join(",\n")
        "\n\"useDefault\": false,\n\"overrides\": [\n#{overrides}]"
      else
        "\"useDefault\": true"
      end
    end

    #
    # Timezone info is needed only at recurring events
    #
    def timezone_needed?
      @recurrence && @recurrence[:freq]
    end

    #
    # JSON representation of local timezone
    #
    def local_timezone_json
      ",\"timeZone\" : \"#{Time.now.getlocal.zone}\""
    end

    #
    # JSON representation of recurrence rules for repeating events
    #
    def recurrence_json
      return unless @recurrence && @recurrence[:freq]

      @recurrence[:until] = @recurrence[:until].strftime('%Y%m%dT%H%M%SZ') if @recurrence[:until]
      rrule = "RRULE:" + @recurrence.collect { |k,v| "#{k}=#{v}" }.join(';').upcase
      @recurrence[:until] = Time.parse(@recurrence[:until]) if @recurrence[:until]

      "\"recurrence\": [\n\"#{rrule}\"],"
    end

    #
    # String representation of an event object.
    #
    def to_s
      "Event Id '#{self.id}'
      \tStatus: #{status}
      \tTitle: #{title}
      \tStarts: #{start_time}
      \tEnds: #{end_time}
      \tLocation: #{location}
      \tDescription: #{description}
      \tAttendees: #{attendees}\n"
    end

    #
    # Saves an event.
    #  Note: make sure to set the calendar before calling this method.
    #
    def save
      update_after_save(@calendar.save_event(self))
    end

    #
    # Deletes an event.
    #  Note: If using this on an event you created without using a calendar object,
    #  make sure to set the calendar before calling this method.
    #
    def delete
      @calendar.delete_event(self)
      @id = nil
    end

    #
    # Returns true if the event will use quickadd when it is saved.
    #
    def use_quickadd?
      quickadd && id == nil
    end

    #
    # Returns true if this a new event.
    #
    def new_event?
      #id == nil || id == ''
      @new_event
    end

    #def ==(other)
      #self.id == other.id
    #end

    protected

    #
    # Create a new event from a google 'entry'
    #
    def self.new_from_feed(e, calendar) #:nodoc:
      event = Event.new(:id           => e['id'],
                :calendar     => calendar,
                :status       => e['status'],
                :raw          => e,
                :title        => e['summary'],
                :description  => e['description'],
                :location     => e['location'],
                :start_time   => Event.parse_json_time(e['start']),
                :end_time     => Event.parse_json_time(e['end']),
                :transparency => e['transparency'],
                :html_link    => e['htmlLink'],
                :updated      => e['updated'],
                :reminders    => e['reminders'],
                :attendees    => e['attendees'],
                :recurrence   => Event.parse_recurrence_rule(e['recurrence']),
                :visibility   => e['visibility'] )
      event.new_event = false
      return event
    end

    #
    # Parse recurrence rule
    # Returns hash with recurrence info
    #
    def self.parse_recurrence_rule(recurrence_entry)
      return {} unless recurrence_entry && recurrence_entry != []

      rrule = /(?<=RRULE:)(.*)(?="\])/.match(recurrence_entry.to_s).to_s
      rhash = Hash[*rrule.downcase.split(/[=;]/)]

      rhash[:until] = Time.parse(rhash[:until]) if rhash[:until]
      rhash
    end

    #
    # Set the ID after google assigns it (only necessary when we are creating a new event)
    #
    def update_after_save(respose) #:nodoc:
      return if @id && @id != ''
      @raw = JSON.parse(respose.body)
      @id = @raw['id']
      @html_link = @raw['htmlLink']
    end

    def self.parse_json_time(time_hash)
      return unless time_hash
      if time_hash['date']
        Time.parse(time_hash['date']).utc
      elsif time_hash['dateTime']
        Time.parse(time_hash['dateTime']).utc
      else
        Time.now.utc
      end
    end

    #
    # A utility method used centralize time parsing.
    #
    def self.parse_time(time) #:nodoc
      raise ArgumentError, "Start Time must be either Time or String" unless (time.is_a?(String) || time.is_a?(Time))
      (time.is_a? String) ? Time.parse(time) : time.dup.utc
    end

    #
    # Validates id format
    #
    def self.parse_id(id)
      raise ArgumentError, "Event ID is invalid. Please check Google documentation: https://developers.google.com/google-apps/calendar/v3/reference/events/insert" unless id.gsub(/(^[a-v0-9]{5,1024}$)/o)      
      return id
    end

  # * +status+ - The status of the event (confirmed, tentative or cancelled).
    def self.parse_status(status)
      raise ArgumentError, "Event status must be 'confirmed', 'tentative' or 'cancelled'." unless ['confirmed', 'tentative', 'cancelled'].include?(status)    
      return status
    end
    #
    # Validates visibility value
    #
    def self.parse_visibility(visibility)
      raise ArgumentError, "Event visibility must be 'default', 'public', 'private' or 'confidential'." unless ['default', 'public', 'private', 'confidential'].include?(visibility)    
      return visibility
    end

  end
end
