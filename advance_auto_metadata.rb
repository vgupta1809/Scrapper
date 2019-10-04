require 'csv'
require 'pry'
module Engine
  class AdvanceAuto
    attr_accessor :data, :advance_auto_makes

    # year make model engine code1 code2
    # 0    1     2     3      4     5
    def initialize(year = nil)
      generate_one_csv
      @data = CSV.read('advance_auto.csv')[1..-1]
      @data = @data[1..-1].select{|d| d[0] == year.to_s } if year
      @advance_auto_makes = {}
      master_make_data
    end

    def csv_headers
      ["year", "Make", "Model", "Engine", "code1","code2"]
    end

    def generate_one_csv
      files = Dir["./advance_autopart/*.csv"].sort
      file_contents = files.map { |f| CSV.read(f) }
      csv_string = CSV.generate do |csv|
        csv << csv_headers
        file_contents.each do |file|
          file.each do |row|
            csv << row
          end
        end
      end
      File.open("advance_auto.csv", "w") { |f| f << csv_string }
    end

    def master_make_data
      @master_make_data ||= CSV.read('master_make.csv')[1..-1]
        @master_make_data.each do |row|
          next unless row[2]
          advance_auto_makes.store(row[2],row[0])
      end
    end

    def fuel_type(engine)
      type = fuel_mappings.keys.detect{ |f| engine.downcase.include?(f.downcase) }
      fuel_mappings[type]
    end

    def size(engine)

      return nil if engine.length < 11 || engine == 'Electric/Hydrogen' || (engine.length < 29 && engine.downcase.include?('electric'))
      size = engine.split(' ')[0].to_f
      size = nil if size.zero?
      return size
    end

    def cylinders(engine)
        return nil if engine.length < 11 || engine == 'Electric/Hydrogen' || (engine.length < 29 && engine.downcase.include?('electric'))
        cylinder = engine.split(' ')[2].delete('V L H W').to_i
        cylinder = nil if cylinder.zero?
        return cylinder
    end

    def vin_size(engine)
      if engine.include?('VIN:')
        return @vin_size = engine.split('VIN:').last.strip
      end
      return nil
    end

    def master_make(row)
      advance_auto_makes[row[1]] || row[1]
    end

    def metdata_info
      engine_with_meta_data = []
      data.each do |row|
        eng = row[3]
        #binding.pry
        engine_with_meta_data <<  ([row[0], master_make(row)] + row[1..3] + [vin_size(eng), size(eng), cylinders(eng), fuel_type(eng), cylinders(eng), fuel_type(eng)] + row[4..-1])
      end
      engine_with_meta_data
    end

    def to_csv
      File.open('advanceauto_metadata.csv', 'w') do |f|
        f.write(([['Year','Make', 'Model', 'Engine', 'cod21', 'code 2', "Make'" ,'Cyclinders', 'Vin Size', 'Size' ,'Fuel Type']] + metdata_info).map(&:to_csv).join)
      end
    end

    private

    def fuel_mappings
      {
      "Nat. Gas" => "Natural Gas",
      "Hybrid" => "Hybrid",
      'Diesel' => "Diesel",
      "Propane" => "Propane",
      "Flex" => "Flex"
      }
    end
  end
end


Engine::AdvanceAuto.new().to_csv