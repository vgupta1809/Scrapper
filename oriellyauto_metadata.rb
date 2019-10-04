require 'csv'
require 'pry'
module Engine
  class Oreilly
    attr_accessor :data, :oreillyauto_makes

    def initialize(year = nil)
      generate_one_csv
      @data = CSV.read('oreillyauto.csv')[1..-1]
      @data = @data[1..-1].select{|d| d[0] == year.to_s } if year
      @oreillyauto_makes = {}
      master_make_data
    end

    def generate_one_csv
      files = Dir["./oreilly/*.csv"].sort
      file_contents = files.map { |f| CSV.read(f) }
      csv_string = CSV.generate do |csv|
        file_contents.each do |file|
          file.each do |row|
            csv << row
          end
        end
      end
      File.open("oreillyauto.csv", "w") { |f| f << csv_string }
    end

    def master_make_data
      @master_make_data ||= CSV.read('master_make.csv')[1..-1]
        @master_make_data.each do |row|
          next unless row[3]
          oreillyauto_makes.store(row[3],row[0]) 
      end
    end

    def fuel_type(engine)
      type = fuel_mappings.keys.detect{ |f| engine.downcase.include?(f.downcase) }
      fuel_mappings[type]
    end

    def size(engine)
      if engine.include?('ELECTRIC') && engine.length <= 31
        @size = nil
      else
        @cylinders, other = engine.split('-')
        @size = other.strip.split(' ').first.strip rescue nil
      end
      @size = @size.to_f
      @size = nil if @size.zero?
      return @size
    end

    def cylinders(engine)
      if engine.length <=14
        @cylinder = engine.split('-').first.strip
      elsif engine.include?('ELECTRIC') && engine.length <= 31
        @cylinder = nil
      else
        @cylinder, other = engine.split('-')
      end
      @cylinder = @cylinder.delete('V L H W') if @cylinder
      @cylinder = @cylinder.to_i
      @cylinder = nil if @cylinder.zero?
      return @cylinder
    end

    def vin_size(engine)
      if engine.include?('vin')
        vin_size = engine.split('vin').last.strip.split(' ').first
      end
      vin_size
    end

    def vin(engine)

      if engine.include?('type')
        vin = engine.split('type').last.strip.split(' ').first 
      end
      if (vin_size(engine) && vin)
        vin = vin_size(engine).to_s + "-" + vin
      end
      if vin.nil?
        vin = vin_size(engine)
      end  
      vin
    end

    def master_make(row)
      oreillyauto_makes[row[1]] || row[1]
    end

    def model(row)
      model = row[2].to_s
      model = model + " " + row[3] unless row[3].downcase == 'base'
      return model.strip
    end

    def metdata_info
      engine_with_meta_data = []
      data.each do |row|
        eng = row[5]
        engine_with_meta_data <<  ([row[0], master_make(row), row[1]] + [model(row), row[2], row[3], row[5]] + [vin(eng), vin_size(eng), vin_size(eng), size(eng), cylinders(eng), fuel_type(eng), cylinders(eng), fuel_type(eng), row[4], row[6]])
      end
      engine_with_meta_data
    end

    def to_csv
      File.open('oreilly_metadata.csv', 'w') do |f|
        f.write(([['Year','Make', 'Model', 'Sub Model', 'Code1','Engine', 'code 2', "Make'" ,'Cyclinders', 'Vin', 'Vin Size', 'Size' ,'Fuel Type']] + metdata_info).map(&:to_csv).join)
      end
    end

    private

    def fuel_mappings
      {
      'ELECTRIC/GAS' => 'Hybrid',
      "ELECTRIC/FLEX" => 'Hybrid',
      "ELECTRIC/DIESEL" => 'Hybrid',
      "ELECTRIC/HYDROGEN" =>'Hybrid',
      "GAS" => 'Gas',
      "CNG" => 'Natural Gas',
      "DIESEL" => 'Diesel',
      "LPG" => 'Propane',
      "FLEX" => 'Flex'
      }
    end
  end
end


Engine::Oreilly.new().to_csv