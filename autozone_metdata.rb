require 'csv'
require 'pry'
module Engine
  class Autozone
    attr_accessor  :data, :autozone_makes, :engine_with_meta_data, :meta_data

    def initialize(year = nil)
      @data = CSV.read('autozone.csv')[1..-1]
      @data = @data[1..-1].select{|d| d[0] == year.to_s } if year
      @autozone_makes = {}
      @engine_with_meta_data = []
      @meta_data = []
      master_make_data
    end

   def match_exist?(year, make, model, engine)
    model = model.downcase
    @wd_entries.select{|d| d[0] == year && make == d[1]}.each do |row|
      if model.downcase.include?('awd') || model.downcase.include?('4wd')
        m = model.gsub('awd','2wd' ).gsub('4wd', '2wd')
        return true if row[0] == year && row[1].downcase == make.downcase && row[2].downcase == m.downcase && row[3].downcase == engine.downcase
      elsif model.include?('2wd')
        m = model.gsub('2wd','4wd')
        return true if row[0] == year && row[1].downcase == make.downcase && row[2].downcase == m.downcase && row[3].downcase == engine.downcase
      end
      if model.include?('2wd')
        m = model.gsub('2wd','awd')
        return true if row[0] == year && row[1].downcase == make.downcase && row[2].downcase == m.downcase && row[3].downcase == engine.downcase
      end  
    end
    false
  end

    def master_make_data
        @master_make_data ||= CSV.read('master_make.csv')[1..-1]
        @master_make_data.each do |row|
          next unless row[1]
          autozone_makes.store(row[1],row[0])
      end
    end

    def fuel_type(engine)
      type = fuel_mappings.keys.detect{ |f| engine.downcase.include?(f.downcase) }
      fuel_mappings[type]
    end

    def size(engine)
      first,second = engine.downcase.split('cylinders').last.split()
      size = Float(first.gsub('.l', '').gsub('l', '')) rescue Float(second.gsub('.l', '').gsub('l', '')) rescue nil

      if (Integer(first) rescue nil)
        size  = Float(second.gsub('.l', '').gsub('l', '')) rescue Float(first)
      end
      size
    end

    def vin(engine)
      first, second = engine.downcase.split('cylinders').last.split()
      vin = nil
      if (Integer(first) rescue nil)
        vin  = first  if  (Float(second.gsub('.l', '').gsub('l', '')) rescue nil)
      else
        vin = first if first.length == 1  
      end
      vin.to_s.capitalize
    end

    def cylinders(engine)
      cylinders = Integer(engine.downcase.split('cylinders').first) rescue nil
    end

   def master_make(row)
    autozone_makes[row[1]] || row[1]
   end

    def metdata_info
      @wd_entries = []
      data.each do |row|
        eng = row[3]
        if row[2].downcase.include?('4wd') || row[2].downcase.include?('2wd') || row[2].downcase.include?('awd')
          next if match_exist?(row[0], row[1], row[2], row[3])
          @wd_entries << row
        end
        engine_with_meta_data <<  ([row[0], master_make(row)] + row[1..3] + [vin(eng),"",""] + [size(eng).to_f, cylinders(eng),fuel_type(eng), fuel_type(eng)] + row[4..-1])
      end
      engine_with_meta_data.uniq
    end

    def to_csv
      File.open('autozone_metadata.csv', 'w') do |f|
      f.write(([['Year','Make', 'Model', 'Engine', 'code', 'Master Make','Cyclinders','Size','Fuel Type']] + metdata_info).map(&:to_csv).join)
      end
    end

    private

    def fuel_mappings
      {
        'Flex/Elec'=> 'Hybrid',
        'Elec/Dsl'=> 'Hybrid',
        'Hybrid' => 'Hybrid',
        'HEV' => 'Hybrid',
        'Diesel' => 'Diesel',
        'Dsl' => 'Diesel',
        'Natural Gas' => "Natural Gas",
        'CNG' => 'Natural Gas',
        'LPG' => 'Propane',
        'FFV' => 'Flex'
      }
    end
  end
end
Engine::Autozone.new().to_csv