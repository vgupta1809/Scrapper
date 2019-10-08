require 'csv'
require 'pry'
module Engine
  class Pepboys
    attr_accessor :engines

    def initialize(year = nil)
      @data = CSV.read('pepboys.csv')[1...-1]
      @data = @data[1..-1].select{|d| d[0] == year.to_s } if year
      #binding.pry
      @pepboys_makes = {}
      master_make_data
      #@engines = data[1..-1].map{ |d| d[6] }.uniq
    end


    def master_make_data
      master_make_data = CSV.read('master_make.csv')[1..-1]
      pepboys_makes = {}
      master_make_data.each do |data|
        next unless data[4]
        @pepboys_makes.store(data[4],data[0]) 
      end
    end

    def engines_with_fuel_type
      pepboys_engines_fuels = []
      engines.each do |engine|
        type = fuel_mappings.keys.detect{ |f| engine.downcase.include?(f.downcase) }
        pepboys_engines_fuels <<  [engine, fuel_mappings[type]]
      end
      pepboys_engines_fuels
    end

    def master_make(row)
      @pepboys_makes[row[1]] || row[1]
    end

    def cylinders(engine)
      cylinder = nil
      cylinder = engine.split('-').first
      cylinder = nil if cylinder.length > 3 || Integer(cylinder) < 3 rescue false
      cylinder = engine.split(' ')[0].delete('V L H W F').to_i
      return cylinder
    end

    def fuel_type(engine, model)
      type = fuel_mappings.keys.detect{ |f| engine.downcase.include?(f.downcase) }
      type = fuel_mappings.keys.detect{ |f| model.downcase.include?(f.downcase) } if type.nil?
      fuel_mappings[type]
    end

    def size(engine)
      size = nil
      size = engine.split(' ')[1]
      size = nil unless (size.length == 4 || size.length == 5) && size.include?('L') && size.include?('.') rescue true
      return size
    end

    def metadata_info
      pepboys_metadata = []
      @data.each do |row|
        eng = row[3]
        #binding.pry
        pepboys_metadata <<  ([row[0], master_make(row)] + row[1..3] + [cylinders(eng), size(eng), fuel_type(eng,row[2]),cylinders(eng) ,fuel_type(eng,row[2])])
      end
      pepboys_metadata
    end

    def to_csv
      File.open('pepboys_metadata.csv', 'w') do |f|
        f.write(([['Year','Make','Make','Model','Engine','No_Of_Cylinder','Size','Fuel_Type','No_Of_Cylinder','Fuel_Type']] + metadata_info).map(&:to_csv).join)
      end
    end

    private

    def fuel_mappings
      {
        "HYBRID" => 'Hybrid',
        "HYBRD" => 'Hybrid',
        "dsl" => 'Diesel',
        "CNG" => 'Natual Gas',
        "DIESEL" => 'Diesel',
        "LPG" => 'Propane',
      }
    end

  end
end

Engine::Pepboys.new().to_csv