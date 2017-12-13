require 'csv'
require_relative 'man_merger'
require_relative 'labtime'

Time.zone = 'Eastern Time (US & Canada)'

class TasciMerger

  def initialize(subject_code, tasci_directory, output_directory)
    @subject_code = subject_code.chomp
    @tasci_directory = tasci_directory.chomp
    @output_directory = output_directory.chomp
    @master_file_path
  end

  def version
    '0.0.1'
  end


  def create_master_list
    puts "New Version"

    master_file_name = File.join(@output_directory, "tasci_master_#{Time.zone.now.strftime("%Y%m%d")}.csv")
    master_file = CSV.open(master_file_name, "wb")

    master_file << %w(file_name file_labtime file_full_time total_epochs start_labtime end_labtime)
    master_file_contents = []

    puts @tasci_directory
    puts File.exists?(@tasci_directory)

    Dir.foreach(@tasci_directory) do |file|
      next if file == '.' or file == '..' or File.extname(file).upcase != ".TASCI"

      puts file

      tasci_file = File.open(File.join(@tasci_directory, file))
      file_info = {}

      ## HEADER INFO
      # Header Line
      tasci_file.readline

      # File Name
      read_line = tasci_file.readline
      matched_name =  /\W*File name \|\W*(.*\.vpd)/i.match(read_line)
      puts "ERROR: #{read_line}" unless matched_name
      file_info[:source_file_name] = matched_name[1]

      # Record Date
      read_line = tasci_file.readline
      matched_date = /RecordDate\W*\|\W*(..)\/(..)\/(....)\W*\|.*/.match(read_line)
      puts "ERROR: #{read_line}" unless matched_date
      #MY_LOG.info "matched_date: #{matched_date[3]} #{matched_date[1]} #{matched_date[2]}"
      file_info[:record_date] = (matched_date ? Time.zone.local(matched_date[3].to_i, matched_date[2].to_i, matched_date[1].to_i) : nil)

      # Record Time
      read_line = tasci_file.readline
      matched_time = /RecordTime\W*\|\W*(..):(..):(..)\W*\|\W*Patient ID\W*\|\W*.*\W*\|/.match(read_line)
      puts "ERROR: #{read_line}" unless matched_time
      file_info[:record_full_time] = ((matched_time and matched_date) ? Time.zone.local(matched_date[3].to_i, matched_date[2].to_i, matched_date[1].to_i, matched_time[1].to_i, matched_time[2].to_i, matched_time[3].to_i) : nil)
      file_info[:record_labtime] = Labtime.parse(file_info[:record_full_time])

      6.times do
        tasci_file.readline
      end

      # Epochs and duration
      read_line = tasci_file.readline
      matched_line = /\W*# Epochs\W*\|\W*(\d+)\W*\|\W*Duration\(S\)\W*\|\W*(\d+)\|/.match(read_line)
      puts "ERROR: #{read_line}" unless matched_line
      file_info[:epochs] = matched_line[1].to_i - 1
      file_info[:epoch_duration] = matched_line[2].to_i

      5.times do
        tasci_file.readline
      end


      first_labtime = nil
      last_labtime = nil

      until tasci_file.eof?
        line = tasci_file.readline

        matched_line = /(\d+)\|\W*(\d+)\|\W*(\d+)\|\W*(\d+)\|\W*(\d\d):(\d\d):(\d\d)\|\W*(.+)\|\W*(.+)\|/.match(line)
        fields = matched_line.to_a
        fields.delete_at(0)

        raise StandardError, "fields should have 9 fields: #{fields.length} #{fields} #{line}" unless fields.length == 9

        # Calculating labtime is tricky - file may span two days
        calculated_line_time = file_info[:record_full_time] + fields[1].to_i.hours + fields[2].to_i.minutes + fields[3].to_i.seconds
        if calculated_line_time.hour == fields[4].to_i and calculated_line_time.min == fields[5].to_i and calculated_line_time.sec == fields[6].to_i
          line_time = calculated_line_time
          line_labtime = Labtime.parse(line_time)
        elsif file_info[:record_full_time].dst? != calculated_line_time.dst?
          if (calculated_line_time.hour - fields[4].to_i).abs == 1 and calculated_line_time.min == fields[5].to_i and calculated_line_time.sec == fields[6].to_i
            line_time = calculated_line_time
            line_labtime = Labtime.parse(line_time)
          else
            raise StandardError, "Times DO NOT MATCH IN TASCI FILE #{File.basename(tasci_file_path)}!!! #{calculated_line_time.to_s} #{fields[4]} #{fields[5]} #{fields[6]}"
          end
        else
          raise StandardError, "Times DO NOT MATCH IN TASCI FILE #{File.basename(tasci_file_path)}!!! #{calculated_line_time.to_s} #{fields[4]} #{fields[5]} #{fields[6]}"
        end

        first_labtime = line_labtime if first_labtime.nil?
        last_labtime = line_labtime

        #MY_LOG.info fields
        #puts fields
      end

      master_file_contents << [file, file_info[:record_labtime].to_short_s, file_info[:record_full_time], file_info[:epochs], first_labtime.to_decimal, last_labtime.to_decimal]
    end

    master_file_contents.sort! {|x, y| x[4] <=> y[4] }
    master_file_contents.each { |row| master_file << row }

    puts "1. Created master file: #{master_file.path}"
    @master_file_path = master_file.path
    master_file_name
    master_file.close 
  end

  def merge_files
    raise StandardError, "No master file path set! You must run create_master_list before running this function." unless @master_file_path

    merged_file = CSV.open(File.join(@output_directory, "#{@subject_code}_merged_#{Time.zone.now.strftime("%Y%m%d")}.csv"), "wb")
    merged_file << %w(SUBJECT_CODE FILE_NAME_SLEEP_WAKE_EPISODE LABTIME SLEEP_STAGE LIGHTS_OFF_ON_FLAG SEM_FLAG)

    simple_merged_file = CSV.open(File.join(@output_directory, "#{@subject_code}_merged_simple_#{Time.zone.now.strftime("%Y%m%d")}.csv"), "wb")
    simple_merged_file << %w(SLEEP_STAGE LABTIME)

    sem_merged_file = CSV.open(File.join(@output_directory, "#{@subject_code}_merged_sem_#{Time.zone.now.strftime("%Y%m%d")}.csv"), "wb")
    simple_merged_file << %w(SUBJECT_CODE LABTIME)

    previous_first_labtime = nil
    previous_last_labtime = nil

    CSV.foreach(@master_file_path, headers: true) do |row|
      puts row
      tasci_file_path = File.join(@tasci_directory, row[0])

      tasci_file = File.open(tasci_file_path)
      file_info = {}

      ## HEADER INFO
      # Header Line
      tasci_file.readline

      # File Name
      read_line = tasci_file.readline
      matched_name =  /\W*File name \|\W*(.*\.vpd)/i.match(read_line)
      puts "ERROR: #{read_line}" unless matched_name
      file_info[:source_file_name] = matched_name[1]

      # Record Date
      read_line = tasci_file.readline
      matched_date = /RecordDate\W*\|\W*(..)\/(..)\/(....)\W*\|.*/.match(read_line)
      puts "ERROR: #{read_line}" unless matched_date
      #MY_LOG.info "matched_date: #{matched_date[3]} #{matched_date[1]} #{matched_date[2]}"
      file_info[:record_date] = (matched_date ? Time.zone.local(matched_date[3].to_i, matched_date[2].to_i, matched_date[1].to_i) : nil)

      # Record Time
      read_line = tasci_file.readline
      matched_time = /RecordTime\W*\|\W*(..):(..):(..)\W*\|\W*Patient ID\W*\|\W*.*_.*_(\w*)\W*\|/.match(read_line)
      puts "ERROR: #{read_line}" unless matched_time
      file_info[:record_full_time] = ((matched_time and matched_date) ? Time.zone.local(matched_date[3].to_i, matched_date[2].to_i, matched_date[1].to_i, matched_time[1].to_i, matched_time[2].to_i, matched_time[3].to_i) : nil)
      file_info[:record_labtime] = Labtime.parse(file_info[:record_full_time])
      file_info[:sleep_wake_episode] = matched_time[4]

      6.times do
        tasci_file.readline
      end

      # Epochs and duration
      read_line = tasci_file.readline
      matched_line = /\W*# Epochs\W*\|\W*(\d+)\W*\|\W*Duration\(S\)\W*\|\W*(\d+)\|/.match(read_line)
      puts "ERROR: #{read_line}" unless matched_line
      file_info[:epochs] = matched_line[1].to_i
      file_info[:epoch_duration] = matched_line[2].to_i

      5.times do
        tasci_file.readline
      end

      first_labtime = nil
      last_labtime = nil

      until tasci_file.eof?
        line = tasci_file.readline

        matched_line = /(\d+)\|\W*(\d+)\|\W*(\d+)\|\W*(\d+)\|\W*(\d\d):(\d\d):(\d\d)\|\W*(.+)\|\W*(.+)\|/.match(line)
        fields = matched_line.to_a
        fields.delete_at(0)

        raise StandardError, "fields should have 9 fields: #{fields.length} #{fields} #{line}" unless fields.length == 9

        # Calculating labtime is tricky - file may span two days
        calculated_line_time = file_info[:record_full_time] + fields[1].to_i.hours + fields[2].to_i.minutes + fields[3].to_i.seconds
        if calculated_line_time.hour == fields[4].to_i and calculated_line_time.min == fields[5].to_i and calculated_line_time.sec == fields[6].to_i
          line_time = calculated_line_time
          line_labtime = Labtime.parse(line_time)
        elsif file_info[:record_full_time].dst? != calculated_line_time.dst?
          if (calculated_line_time.hour - fields[4].to_i).abs == 1 and calculated_line_time.min == fields[5].to_i and calculated_line_time.sec == fields[6].to_i
            line_time = calculated_line_time
            line_labtime = Labtime.parse(line_time)
          else
            raise StandardError, "Times DO NOT MATCH IN TASCI FILE #{File.basename(tasci_file_path)}!!! #{calculated_line_time.to_s} #{fields[4]} #{fields[5]} #{fields[6]}"
          end
        else
          raise StandardError, "Times DO NOT MATCH IN TASCI FILE #{File.basename(tasci_file_path)}!!! #{calculated_line_time.to_s} #{fields[4]} #{fields[5]} #{fields[6]}"
        end

        # Sleep Period Coding:
        # 1      Sleep Onset (Lights Off)
        # 2      Sleep Offset (Lights On)
        if /Lights Off|LOff|LightsOn/i.match(fields[7]) # Sleep Onset
          sleep_period = 1
        elsif /Lights On|LOn|LightsOn/i.match(fields[7]) # Sleep Offset
          sleep_period = 2
        else
          sleep_period = nil
        end

        # Sleep Stage Coding:
        # 1      stage 1
        # 2      stage 2
        # 3      stage 3
        # 4      stage 4
        # 6      MT
        # 7      Undef
        # 5      REM
        # 9      Wake
        line_event = nil
        if fields[8] == "Wake" || fields[8] == 'Awake'
          line_event = 9
        elsif fields[8] == "Undefined"
          line_event = 7
        elsif fields[8] == "N1" ||  fields[8] == '1'
          line_event = 1
        elsif fields[8] == "N2" ||  fields[8] == '2'
          line_event = 2
        elsif fields[8] == "N3" ||  fields[8] == '3'
          line_event = 3
        elsif fields[8] == "N4" || fields[8] == '4'
          line_event = 4
        elsif fields[8] == "REM"
          line_event = 5
        elsif fields[8] == "MVT"
          line_event = 6
        else
          raise StandardError, "Cannot map the following event: #{fields[8]}"
        end

        # SEM Event Coding:
        # 1      Slow Eye Movement
        # 0      No Slow Eye Movement
        sem_event = (fields[7] =~ /SEM/ ? 1 : 0)




        # Alternate Coding:
        # 0 - UNDEF
        # 1 - N1
        # 2 - N2
        # 3 - N3
        # 4 - 4
        # 5 - Wake
        # 6 - REM
        # 7 - MT
        # 8 - Sleep Onset (LIGHTS OFF)
        # 9 - Lights On

        ### SLEEP STAGE, LABTIME
        simple_line_event = nil
        if fields[8] == "Wake" || fields[8] == 'Awake'
          simple_line_event = 5
        elsif fields[8] == "Undefined"
          simple_line_event = 0
        elsif fields[8] == "N1" || fields[8] == '1'
          simple_line_event = 1
        elsif fields[8] == "N2" || fields[8] == '2'
          simple_line_event = 2
        elsif fields[8] == "N3" || fields[8] == '3'
          simple_line_event = 3
        elsif fields[8] == "N4" || fields[8] == '4'
          simple_line_event = 4
        elsif fields[8] == "REM"
          simple_line_event = 6
        elsif fields[8] == "MVT"
          simple_line_event = 7
        else
          raise StandardError, "Cannot map the following event: #{fields[8]}"
        end

        if sleep_period == 1
          simple_line_event = 8
        elsif sleep_period == 2
          simple_line_event = 9
        end
        
        first_labtime = line_labtime if first_labtime.nil?
        last_labtime = line_labtime

        output_line = [@subject_code.upcase, file_info[:sleep_wake_episode], line_labtime.to_decimal, line_event, sleep_period, sem_event]
        simple_output_line = [simple_line_event, line_labtime.to_decimal]
        sem_output_line = [@subject_code.upcase, line_labtime.to_decimal] if sem_event == 1

        merged_file << output_line
        simple_merged_file << simple_output_line
        sem_merged_file << sem_output_line if sem_event == 1

        #MY_LOG.info fields
      end


      unless previous_first_labtime.nil? or previous_last_labtime.nil?
        puts "Start time is before previous end labtime: #{previous_last_labtime.to_short_s} #{first_labtime.to_short_s}" if first_labtime < previous_last_labtime
      end


      previous_first_labtime = first_labtime
      previous_last_labtime = last_labtime
    end
    merged_file.close
    simple_merged_file.close
    sem_merged_file.close
  end

end

