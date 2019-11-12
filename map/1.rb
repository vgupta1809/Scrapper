require 'csv'
require 'json'
require 'pry'

class Mapping
  attr_accessor :advance_auto_data, :autozone_data, :oreillyauto_data, :pepboys_data

    def initialize(year = nil)
      @year = year
      @master_engines = {}
      csv_data = []
      @new_master_engines = {}
      @advance_auto_data, @autozone_data, @oreillyauto_data, @pepboys_data = load_autozone_data_from_csv(year)
      csv_data = worker(year)
      csv_data = retailer(csv_data, year)
      #csv_data = retailer_wd(csv_data)
      csv_data = sort_models(csv_data)
      csv_data = remove_redundant(csv_data)
      csv_data = write_file(csv_data,year)
    end

def load_autozone_data_from_csv(year)
  advance_auto_data = CSV.read('advanceauto_metadata.csv').select{|d| d if d[0] == year}
  autozone_data = CSV.read('autozone_metadata.csv').select{|d| d if d[0] == year}
  oreillyauto_data = CSV.read('oreilly_metadata.csv').select{|d| d if d[0] == year}
  pepboys_data = CSV.read('pepboys_metadata.csv').select{|d| d if d[0] == year}
  return advance_auto_data, autozone_data, oreillyauto_data, pepboys_data 
end

def load_autoparts_makes(advance_auto_data, autozone_data, oreillyauto_data, pepboys_data)
  advance_auto_makes = advance_auto_data.map{|d| d[1]}.uniq
  autozone_makes = autozone_data.map{|d| d[1]}.uniq
  oreillyauto_makes = oreillyauto_data.map{|d| d[1]}.uniq
  pepboys_makes = pepboys_data.map{|d| d[1]}.uniq
  return advance_auto_makes, autozone_makes, oreillyauto_makes, pepboys_makes
end

def load_autoparts_models(advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make)
  advance_auto_models = advance_auto_data.map{|d| d[3] if d[1].downcase == make }.compact.uniq.sort_by(&:length).reverse
  autozone_models = autozone_data.map{|d| d[3] if d[1].downcase == make }.compact.uniq.sort_by(&:length).reverse
  oreillyauto_base_models = oreillyauto_data.map{|d| d[4].downcase if d[1].downcase == make }.compact.uniq.sort_by(&:length).reverse
  oreillyauto_models = oreillyauto_data.map{|d| d[3] if d[1].downcase == make }.compact.uniq.sort_by(&:length).reverse
  pepboys_models = pepboys_data.map{|d| d[3] if d[1].downcase == make }.compact.uniq.sort_by(&:length).reverse
  return advance_auto_models, autozone_models, oreillyauto_base_models, oreillyauto_models, pepboys_models  
end

def target_model_match(retailer, make, m, model_word_count, models, oreillyauto_base_models)
  if ((@year.to_i < 2001) && (['chevrolet', 'gmc'].include? make.downcase) && (['pepboys', 'autozone'].include? retailer.downcase) && (m.split.first.downcase == 'express'))
    m = m.gsub('express ', 'g')
    target_models = models.map(&:downcase).select{ |c| oreillyauto_base_models.any?{ |k| k.gsub('express ', 'g')[0..1].start_with?(c.gsub('-','')[0..1]) && m.gsub('express ', 'g')[0..1].include?(k.gsub('express ', 'g')[0..1]) } if m.gsub('express ', 'g')[0..1].include?(c.gsub('-','')[0..1]) }
  elsif (['chevrolet', 'gmc'].include? make.downcase) && (['autozone'].include? retailer.downcase) && (m.downcase.include? 'pickup')
    target_models = models.map(&:downcase).select{ |c| oreillyauto_base_models.any?{ |k| k.gsub('-','')[0..1].start_with?(c.gsub('-','')[0..1]) && m.gsub('-','')[0..1].include?(k.gsub('-','')[0..1]) && (c.include? 'p/u') } if (m.gsub('-','')[0..1].include?(c.gsub('-','')[0..1]) && (m.include? 'pickup')) }
  elsif (['chevrolet', 'gmc'].include? make.downcase) && (['autozone'].include? retailer.downcase) && (m.downcase.include? 'suburban')
    target_models = models.map(&:downcase).select{ |c| oreillyauto_base_models.any?{ |k| k.gsub('-','')[0..1].start_with?(c.gsub('-','')[0..1]) && m.gsub('-','')[0..1].include?(k.gsub('-','')[0..1]) && (c.include? 'sub') } if (m.gsub('-','')[0..1].include?(c.gsub('-','')[0..1]) && (m.include? 'suburban')) }
  elsif (['chevrolet', 'gmc'].include? make.downcase) && (['advance_auto'].include? retailer.downcase) && (m.downcase.include? 'suburban')
    target_models = models.map(&:downcase).select{ |c| oreillyauto_base_models.any?{ |k| k.split.first[0..4].start_with?(c.split.last[0..4]) && (m.split.first[0..4].include?(k.split.first[0..4])) && (c.include? 'suburban') } if (m.split.first[0..4].include?(c.split.last[0..4]) && (m.include? 'suburban')) }    
  else
    target_models = models.map(&:downcase).select{ |c| oreillyauto_base_models.any?{ |k| k.gsub('-','')[0..1].start_with?(c.gsub('-','')[0..1]) && m.gsub('-','')[0..1].include?(k.gsub('-','')[0..1]) } if m.gsub('-','')[0..1].include?(c.gsub('-','')[0..1]) }
  end  
  (0..model_word_count-1).each do |count|
    tmp_m = m.gsub('-','').split[0..count].join(' ')
    new_matched_models = target_models.select{ |c| c if c.gsub('-','').split[0..count].join(' ').downcase == tmp_m.downcase }
    new_matched_models = target_models.select{ |c| c if c.gsub('-','').start_with?(tmp_m) } if new_matched_models.empty?
    new_matched_models = target_models.select{ |c| c if tmp_m.start_with?(c.gsub('-','').split[0..count].join(' ').downcase) } if new_matched_models.empty?
    new_matched_models.empty? ? break : (target_models = new_matched_models)
  end
  target_models
end

def match_exist?(master_data, retailer, engine, model)
  master_data.each do |data|
   data.last.values.each do |elm|
      eng,m = elm[retailer.to_sym]
      return true if eng == engine && m == model
    end
  end
  false
end

def load_autopats_engines(make, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data)
  @advance_auto_engine = advance_auto_data.select{|d| d if d[1].downcase == make.downcase && d[3] == @advance_auto_model}.map{ |d| d[4]}
  @autozone_engine = autozone_data.select{|d| d if d[1].downcase == make.downcase && d[3] == @autozone_model}.map{ |d| d[4]}
  @oreillyauto_engine = oreillyauto_data.select{|d| d if d[1].downcase == make.downcase && d[3] == @oreillyauto_model}.map{ |d| d[6]}
  @pepboys_engine = pepboys_data.select{|d| d if d[1].downcase == make.downcase && d[3] == @pepboys_model}.map{ |d| d[4]}
end

def exact_model_match(advance_auto_models, autozone_models, oreillyauto_models, pepboys_models, m)
  @advance_auto_model = (@advance_auto_index = advance_auto_models.map(&:downcase).index(m)) ? advance_auto_models[@advance_auto_index] : nil
  @autozone_model =  (@autozone_index = autozone_models.map(&:downcase).index(m)) ? autozone_models[@autozone_index] : nil
  @oreillyauto_model = (@oreillyauto_index = oreillyauto_models.map(&:downcase).index(m)) ? oreillyauto_models[@oreillyauto_index] : nil
  @pepboys_model =  (@pepboys_index = pepboys_models.map(&:downcase).index(m)) ? pepboys_models[@pepboys_index] : nil #exact match
end  

def pepboys_similar_model_match(e, make, oreillyauto_data, m, pepboys_models, oreillyauto_base_models, pepboys_data, rematch, model_word_count, ocylinder, osize, otype, ovin)
  target_models = target_model_match('pepboys', make, m, model_word_count, pepboys_models, oreillyauto_base_models)
  target_models.sort.reverse.each do |tm|
    break unless @pepboys_model.nil?
    rtm = (@pepboys_index = pepboys_models.map(&:downcase).index(tm)) ? pepboys_models[@pepboys_index] : nil
    @pepboys_engine = pepboys_data.select{|d| d if d[3] == rtm}.map{ |d| d[4]}
    @pepboys_engine.sort_by(&:length).reverse.each do |ae|
      next if match_exist?(@master_engines[make], 'pepboys', ae, rtm) unless rematch
      acylinder, asize, atype = pepboys_engine_details(tm, ae, pepboys_data)
      unless atype.nil?
        @pepboys_model = rtm if asize == osize && acylinder == ocylinder && atype == otype
        @pepboys_engine_match << ae
      else
        @pepboys_model = rtm if asize == osize && acylinder == ocylinder
        @pepboys_engine_match << ae
      end
    end
  end
  @pepboys_engine = @pepboys_engine_match.uniq
end

def autozone_similar_model_match(e, make, oreillyauto_data, m, autozone_models, oreillyauto_base_models, autozone_data, rematch, model_word_count, ocylinder, osize, otype, ovin)
  target_models = target_model_match('autozone', make, m ,model_word_count, autozone_models, oreillyauto_base_models)
    target_models.sort.reverse.each do |tm|
      break unless @autozone_model.nil?
      rtm = (@autozone_index = autozone_models.map(&:downcase).index(tm)) ? autozone_models[@autozone_index] : nil
      @autozone_engine = autozone_data.select{|d| d if d[3] == rtm}.map{ |d| d[4]}      
      @autozone_engine.sort_by(&:length).reverse.each do |ae|
        #next if match_exist?(@master_engines[make], 'autozone', ae, rtm) unless rematch
        acylinder,asize ,atype, avin = autozone_engine_details(m, ae, autozone_data)
        unless atype.nil?
          @autozone_model = rtm if asize == osize && acylinder == ocylinder && atype == otype
          @autozone_engine_match << ae if asize == osize && acylinder == ocylinder && atype == otype
        else
          @autozone_model = rtm if asize == osize && acylinder == ocylinder
          @autozone_engine_match << ae if asize == osize && acylinder == ocylinder
        end  
      end
    end
  @autozone_engine = @autozone_engine_match.uniq 
end

def advance_auto_similar_model_match(e, make, oreillyauto_data, m, advance_auto_models, oreillyauto_base_models, advance_auto_data, rematch, model_word_count, ocylinder, osize, otype, ovin)
  target_models = target_model_match('advance_auto', make, m, model_word_count, advance_auto_models, oreillyauto_base_models)
  target_models.sort.reverse.each do |tm|
    break unless  @advance_auto_model.nil?
    rtm = (@advance_auto_index = advance_auto_models.map(&:downcase).index(tm)) ? advance_auto_models[@advance_auto_index] : nil
    @advance_auto_engine = advance_auto_data.select{|d| d if d[3] == rtm}.map{ |d| d[4]}
    @advance_auto_engine.sort_by(&:length).reverse.each do |ae|
      next if match_exist?(@master_engines[make], 'advance_auto', ae, rtm) unless rematch
      acylinder, asize, atype, avin = advance_auto_engine_details(m, ae, advance_auto_data)
      if atype.nil? 
        @advance_auto_model = rtm if (osize.to_f == asize.to_f + 0.1 || osize.to_f == asize.to_f - 0.1 || asize == osize) && acylinder == ocylinder
        @advance_auto_engine_match << ae if osize == asize && (osize.to_f == asize.to_f + 0.1 || osize.to_f == asize.to_f - 0.1 || asize == osize)
      else
        @advance_auto_model = rtm if osize == asize && (osize.to_f == asize.to_f + 0.1 || osize.to_f == asize.to_f - 0.1 || asize == osize) && atype == otype
        @advance_auto_engine_match << ae if osize == asize && (osize.to_f == asize.to_f + 0.1 || osize.to_f == asize.to_f - 0.1 || asize == osize) && atype == otype
      end 
    end
  end
  @advance_auto_engine = @advance_auto_engine_match.uniq
end

def oreillyauto_similar_model_match(e, make, m, oreillyauto_models, oreillyauto_base_models, oreillyauto_data, rematch, model_word_count, ocylinder, osize, otype, ovin)
  target_models = target_model_match('oreillyauto', make, m, model_word_count, oreillyauto_models, oreillyauto_base_models)
  target_models.sort.reverse.each do |tm|
    break unless  @oreillyauto_model.nil?
    rtm = (@oreillyauto_index = oreillyauto_models.map(&:downcase).index(tm)) ? oreillyauto_models[@oreillyauto_index] : nil
    @oreillyauto_engine = oreillyauto_data.select{|d| d if d[1].downcase == make.downcase && d[3] == rtm}.map{ |d| d[6]}
    @oreillyauto_engine.sort_by(&:length).reverse.each do |ae|
      next if match_exist?(@master_engines[make], 'oreillyauto', ae, rtm) unless rematch
      acylinder, asize, atype, avin = oreillyauto_engine_details(m, ae, oreillyauto_data)
      if atype.nil? || otype.nil?
        @oreillyauto_model = rtm if osize == asize && acylinder == ocylinder
        @oreillyauto_engine_match << ae if osize == asize && acylinder == ocylinder
      else
        @oreillyauto_model = rtm if osize == asize && acylinder == ocylinder && atype == otype
        @oreillyauto_engine_match << ae if osize == asize && acylinder == ocylinder && atype == otype
      end 
    end
  end
  @oreillyauto_engine = @oreillyauto_engine_match.uniq
end

def target_to_master(models, retailer, data, make)
  models.each do |m|
    engine = data.select{|d| d if d[3] == m}.map{ |d| d[4]}
    engine.sort_by(&:length).reverse.each do |e|
      model_data = {}
      e = e.strip
      next if match_exist?(@master_engines[make], retailer, e, m)
      model_data[retailer.to_sym] = e, m
      @master_engines[make][m] ||= {}
      @master_engines[make][m][e] ||= model_data
    end
  end
end

def advance_auto_engine_details(m, ae, advance_auto_data)
  aindex = advance_auto_data.find_index { |row| row if ae.strip == row[4].strip && row[3].downcase == m.downcase }
  aindex = advance_auto_data.find_index { |row| row if ae.strip == row[4].strip } if aindex.nil?
  asize = advance_auto_data[aindex][6].delete("L ") rescue nil
  acylinder = advance_auto_data[aindex][9]
  atype = advance_auto_data[aindex][10]
  avin = advance_auto_data[aindex][5].delete('-') rescue nil
  return acylinder, asize, atype, avin
end  

def autozone_engine_details(m, ae, autozone_data)
  aindex = autozone_data.find_index{ |row| row if ae.strip == row[4].strip && row[3].downcase == m.downcase }
  aindex = autozone_data.find_index{ |row| row if ae.strip == row[4].strip } if aindex.nil?
  acylinder = autozone_data[aindex][9]
  asize = autozone_data[aindex][8].delete("L ") rescue nil
  atype = autozone_data[aindex][11]
  avin = autozone_data[aindex][5] rescue nil
  return acylinder, asize, atype, avin
end

def oreillyauto_engine_details(m, e, oreillyauto_data)
  oindex = oreillyauto_data.find_index { |row| row if e.strip == row[6].strip && row[3].downcase == m.downcase }
  oindex = oreillyauto_data.find_index { |row| row if e.strip == row[6].strip } if oindex.nil?
  ocylinder = oreillyauto_data[oindex][13]
  osize = oreillyauto_data[oindex][10].delete("L ") rescue nil
  otype = oreillyauto_data[oindex][14]
  ovin = oreillyauto_data[oindex][7].delete('-') rescue nil
  return ocylinder, osize, otype, ovin
end

def pepboys_engine_details(m, ae, pepboys_data)
  aindex = pepboys_data.find_index { |row| row if ae.strip == row[4].strip && row[3].downcase == m.downcase }
  aindex = pepboys_data.find_index { |row| row if ae.strip == row[4].strip} if aindex.nil?
  acylinder = pepboys_data[aindex][8]
  asize = pepboys_data[aindex][6].delete("L ") rescue nil
  atype = pepboys_data[aindex][9]
  return acylinder, asize, atype 
end  

def pepboys_engine_mapper(d,e,advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
  if make.downcase == 'subaru'
    @pepboys_engine.sort_by(&:length).reverse.each do |ae|
      break unless d[:pepboys].nil?
      next unless e.split.last.downcase == ae.split.last.downcase
      acylinder, asize, atype = pepboys_engine_details(@pepboys_model, ae, pepboys_data)
      d[:pepboys] = ae.strip, @pepboys_model if asize == osize && acylinder == ocylinder && atype == otype unless atype.nil?
      if (d[:pepboys].nil? && (atype.nil? || otype.nil?))
        d[:pepboys] = ae.strip, @pepboys_model if asize == osize && acylinder == ocylinder
      end
    end
  end
  @pepboys_engine.sort_by(&:length).reverse.each do |ae|
    next if match_exist?(@master_engines[make], 'pepboys', ae, @pepboys_model) || @pepboys_model.nil? 
    break unless d[:pepboys].nil?
    acylinder, asize, atype = pepboys_engine_details(@pepboys_model, ae, pepboys_data)
    d[:pepboys] = ae.strip, @pepboys_model if asize == osize && acylinder == ocylinder && atype == otype unless atype.nil?
  end

if d[:pepboys].nil?
  @pepboys_engine.sort_by(&:length).reverse.each do |ae|
    next if match_exist?(@master_engines[make], 'pepboys', ae, @pepboys_model) || @pepboys_model.nil? 
    break unless d[:pepboys].nil?
    acylinder, asize, atype = pepboys_engine_details(@pepboys_model, ae, pepboys_data)
    unless atype.nil?
      d[:pepboys] = ae.strip, @pepboys_model if asize == osize && acylinder == ocylinder && atype == otype
    else
      d[:pepboys] = ae.strip, @pepboys_model if asize == osize && acylinder == ocylinder
    end
  end
end

  if d[:pepboys].nil?
    @pepboys_engine.sort_by(&:length).reverse.each do |ae|
      break unless d[:pepboys].nil?
      next if @pepboys_model.nil?
      acylinder, asize, atype = pepboys_engine_details(@pepboys_model, ae, pepboys_data)
      unless atype.nil?
        d[:pepboys] = ae.strip, @pepboys_model if asize == osize && acylinder == ocylinder && atype == otype
      else
        d[:pepboys] = ae.strip, @pepboys_model if asize == osize && acylinder == ocylinder
      end
    end
  end
  d[:pepboys]
end

def oreillyauto_engine_mapper(d,e,advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)

  @oreillyauto_engine.sort_by(&:length).reverse.each do |ae|
    next if match_exist?(@master_engines[make], 'oreillyauto', ae, @oreillyauto_model)
    break unless d[:oreillyauto].nil?
    acylinder, asize, atype = oreillyauto_engine_details(m, ae, oreillyauto_data)
    d[:oreillyauto] = ae.strip, @oreillyauto_model if asize == osize && acylinder == ocylinder && atype == otype unless atype.nil? || otype.nil?
  end


if d[:oreillyauto].nil?
  @oreillyauto_engine.sort_by(&:length).reverse.each do |ae|
    next if match_exist?(@master_engines[make], 'oreillyauto', ae, @oreillyauto_model)
    break unless d[:oreillyauto].nil?
    acylinder, asize, atype = oreillyauto_engine_details(m, ae, oreillyauto_data)
    unless atype.nil? || otype.nil?
      d[:oreillyauto] = ae.strip, @oreillyauto_model if asize == osize && acylinder == ocylinder && atype == otype
    else
      d[:oreillyauto] = ae.strip, @oreillyauto_model if asize == osize && acylinder == ocylinder
    end
  end
end

  if d[:oreillyauto].nil?
    @oreillyauto_engine.sort_by(&:length).reverse.each do |ae|
      break unless d[:oreillyauto].nil?
      acylinder, asize, atype = oreillyauto_engine_details(m, ae, oreillyauto_data)
      unless atype.nil? || otype.nil?
        d[:oreillyauto] = ae.strip, @oreillyauto_model if asize == osize && acylinder == ocylinder && atype == otype
      else
        d[:oreillyauto] = ae.strip, @oreillyauto_model if asize == osize && acylinder == ocylinder
      end
    end
  end
    d[:oreillyauto]
end

def advance_auto_engine_mapper(d,e,advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)

  @advance_auto_engine.sort_by(&:length).reverse.each do |ae|
    next if match_exist?(@master_engines[make], 'advance_auto', ae, @advance_auto_model)
    break unless d[:advance_auto].nil?
    acylinder, asize, atype, avin = advance_auto_engine_details(m, ae, advance_auto_data)
    unless avin.nil? || ovin.nil?  
      d[:advance_auto] = ae.strip, @advance_auto_model if (osize.to_f == asize.to_f + 0.1 || osize.to_f == asize.to_f - 0.1 || asize == osize) && acylinder == ocylinder && atype == otype && avin == ovin
      d[:advance_auto] = ae.strip, @advance_auto_model if (osize.to_f == asize.to_f + 0.1 || osize.to_f == asize.to_f - 0.1 || asize == osize) && acylinder == ocylinder && atype == otype && (ovin.include?(avin) || avin.include?(ovin)) && (ovin[0] == avin[0]) if d[:advance_auto].nil?
      break if avin == ovin unless d[:advance_auto].nil?
    else
      d[:advance_auto] = ae.strip, @advance_auto_model if osize == asize && acylinder == ocylinder && atype == otype unless atype.nil? || otype.nil?
    end
  end

if d[:advance_auto].nil?
  @advance_auto_engine.sort_by(&:length).reverse.each do |ae|
    next if match_exist?(@master_engines[make], 'advance_auto', ae, @advance_auto_model)
    break unless d[:advance_auto].nil?
    acylinder, asize, atype, avin = advance_auto_engine_details(m, ae, advance_auto_data)
    unless avin.nil? || ovin.nil?
      d[:advance_auto] = ae.strip, @advance_auto_model if (osize.to_f == asize.to_f + 0.1 || osize.to_f == asize.to_f - 0.1 || asize == osize) && acylinder == ocylinder && atype == otype && avin == ovin
      d[:advance_auto] = ae.strip, @advance_auto_model if (osize.to_f == asize.to_f + 0.1 || osize.to_f == asize.to_f - 0.1 || asize == osize) && acylinder == ocylinder && atype == otype && (ovin.include?(avin) || avin.include?(ovin)) && (ovin[0] == avin[0]) if d[:advance_auto].nil?
      break if avin == ovin unless d[:advance_auto].nil?
    else
      if atype.nil? 
        d[:advance_auto] = ae.strip, @advance_auto_model if osize == asize && acylinder == ocylinder
      else
        d[:advance_auto] = ae.strip, @advance_auto_model if osize == asize && acylinder == ocylinder && atype == otype
      end
    end
  end
end

  if d[:advance_auto].nil?
    @advance_auto_engine.sort_by(&:length).reverse.each do |ae|
      break unless d[:advance_auto].nil?
      acylinder, asize, atype, avin = advance_auto_engine_details(m, ae, advance_auto_data)
      unless avin.nil? || ovin.nil?
        if atype.nil? 
          d[:advance_auto] = ae.strip, @advance_auto_model if (osize.to_f == asize.to_f + 0.1 || osize.to_f == asize.to_f - 0.1 || asize == osize) && acylinder == ocylinder && (ovin.include?(avin) || avin.include?(ovin)) && (ovin[0] == avin[0])
        else
          d[:advance_auto] = ae.strip, @advance_auto_model if (osize.to_f == asize.to_f + 0.1 || osize.to_f == asize.to_f - 0.1 || asize == osize) && acylinder == ocylinder && atype == otype && (ovin.include?(avin) || avin.include?(ovin)) && (ovin[0] == avin[0])
        end
      end
    end
  end

  if d[:advance_auto].nil?
    @advance_auto_engine.sort_by(&:length).reverse.each do |ae|
      break unless d[:advance_auto].nil?
      acylinder, asize, atype, avin = advance_auto_engine_details(m, ae, advance_auto_data)
      unless atype.nil? || otype.nil?
        d[:advance_auto] = ae.strip, @advance_auto_model if osize == asize && acylinder == ocylinder && atype == otype
      end
    end
  end

  if d[:advance_auto].nil?
    @advance_auto_engine.sort_by(&:length).reverse.each do |ae|
      break unless d[:advance_auto].nil?
      acylinder, asize, atype, avin = advance_auto_engine_details(m, ae, advance_auto_data)
      if atype.nil? 
        d[:advance_auto] = ae.strip, @advance_auto_model if osize == asize && acylinder == ocylinder
      else
        d[:advance_auto] = ae.strip, @advance_auto_model if asize == osize && acylinder == ocylinder && atype == otype
      end
    end
  end
    d[:advance_auto]
end

def autozone_engine_mapper(d,e,advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
  if make.downcase == 'subaru'
   @autozone_engine = autozone_data.select{|d| d if d[1].downcase == make.downcase && d[3] == @autozone_model}.map{ |d| d[4]}
   @autozone_engine.sort_by(&:length).reverse.each do |ae|
     break unless d[:autozone].nil?
     acylinder,asize ,atype, avin = autozone_engine_details(m, ae, autozone_data)
     next unless e.split.last.downcase == ae.split.last.downcase
       d[:autozone] = ae.strip, @autozone_model if osize == asize && acylinder == ocylinder && atype == otype unless atype.nil? || otype.nil?
      if (d[:autozone].nil? && (atype.nil? || otype.nil?))
        d[:autozone] = ae.strip, @autozone_model if osize == asize && acylinder == ocylinder 
      end
    end
  end

  if make.downcase == 'volkswagen'
    @autozone_engine = autozone_data.select{|d| d if d[1].downcase == make.downcase && d[3] == @autozone_model}.map{ |d| d[4]}
    @autozone_engine.sort_by(&:length).reverse.each do |ae|
      break unless d[:autozone].nil?
      acylinder,asize ,atype, avin = autozone_engine_details(m, ae, autozone_data)
      if ae.downcase.include? 'pzev'
        next if ovin.nil?
        next unless ['cbfa', 'cbua', 'bpr', 'bgq'].include? ovin.downcase
        d[:autozone] = ae.strip, @autozone_model if osize == asize && acylinder == ocylinder && atype == otype unless atype.nil? || otype.nil?
        if (d[:autozone].nil? && (atype.nil? || otype.nil?))
          d[:autozone] = ae.strip, @autozone_model if osize == asize && acylinder == ocylinder 
        end  
      end
    end
    if d[:autozone].nil?
      @autozone_engine.sort_by(&:length).reverse.each do |ae|
        next if ae.downcase.include? 'pzev'
        break unless d[:autozone].nil?
        acylinder,asize ,atype, avin = autozone_engine_details(m, ae, autozone_data)
        unless atype.nil?
          d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && atype == otype
        else
          d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder
        end
      end      
    end
  end
if d[:autozone].nil?
  @autozone_engine.sort_by(&:length).reverse.each do |ae|
    next if match_exist?(@master_engines[make], 'autozone', ae, @autozone_model)
    break unless d[:autozone].nil?
    acylinder,asize ,atype, avin = autozone_engine_details(m, ae, autozone_data)
    unless avin.nil? || ovin.nil?
      next if avin.empty? || ovin.empty?
      d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && atype == otype && avin == ovin
      d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && atype == otype && (ovin[0] == avin[0]) if d[:autozone].nil?
      d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && (ovin[0] == avin[0]) if (d[:autozone].nil? && (atype.nil? || otype.nil?))
      break if (ovin[0] == avin[0]) unless d[:autozone].nil?
    else
      d[:autozone] = ae.strip, @autozone_model if osize == asize && acylinder == ocylinder && atype == otype unless atype.nil? || otype.nil?
    end
  end
end
if d[:autozone].nil?
  @autozone_engine.sort_by(&:length).reverse.each do |ae|
    next if match_exist?(@master_engines[make], 'autozone', ae, @autozone_model)
    break unless d[:autozone].nil?
    acylinder,asize ,atype, avin = autozone_engine_details(m, ae, autozone_data)
    unless avin.nil? || ovin.nil?
      d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && atype == otype && avin == ovin
      d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && atype == otype && (ovin[0] == avin[0]) if d[:autozone].nil?
      break if (ovin[0] == avin[0]) unless d[:autozone].nil?
    else
      if atype.nil? 
        d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder
      else
        d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && atype == otype
      end
    end
  end
end

  if d[:autozone].nil?
    @autozone_engine.sort_by(&:length).reverse.each do |ae|
      break unless d[:autozone].nil?
      acylinder,asize ,atype, avin = autozone_engine_details(m, ae, autozone_data)
      unless avin.nil? || ovin.nil?
        if atype.nil?
          d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && (ovin.include?(avin) || avin.include?(ovin)) && (ovin[0] == avin[0])
        else
          d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && atype == otype && (ovin.include?(avin) || avin.include?(ovin)) && (ovin[0] == avin[0])
        end
      end
    end
  end

if d[:autozone].nil?
  @autozone_engine.sort_by(&:length).reverse.each do |ae|
    next if match_exist?(@master_engines[make], 'autozone', ae, @autozone_model)
    break unless d[:autozone].nil?
    acylinder,asize ,atype, avin = autozone_engine_details(m, ae, autozone_data)
    unless atype.nil?
      d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && atype == otype
    else
      d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder
    end
  end
end  

  if d[:autozone].nil?
    @autozone_engine.sort_by(&:length).reverse.each do |ae|
      break unless d[:autozone].nil?
      acylinder,asize ,atype, avin = autozone_engine_details(m, ae, autozone_data)
      unless atype.nil?
        d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder && atype == otype
      else
        d[:autozone] = ae.strip, @autozone_model if asize == osize && acylinder == ocylinder
      end
    end      
  end
  d[:autozone]
end

def write_csv_data(oreillyauto_makes, year)
  csv_data = []
  oreillyauto_makes.map(&:downcase).uniq.each do |make|
    @master_engines[make].keys.sort_by(&:length).reverse.each_with_index do |k, i|
      @master_engines[make][k].keys.each_with_index do |e, j|
        m = @master_engines[make][k][e]
        make_value = make.split(/(\W)/).map(&:capitalize).join
        oreillyauto_model = m[:oreillyauto].last unless m[:oreillyauto].nil?
        master_model = k.downcase == oreillyauto_model.downcase ? oreillyauto_model : k rescue k
        master_engine = e.strip
        autozone_model = m[:autozone].last unless m[:autozone].nil?
        autozone_engine = m[:autozone].first unless m[:autozone].nil?
        advance_auto_model = m[:advance_auto].last unless m[:advance_auto].nil? 
        advance_auto_engine = m[:advance_auto].first unless m[:advance_auto].nil?
        pepboys_model = m[:pepboys].last unless m[:pepboys].nil?
        pepboys_engine = m[:pepboys].first unless m[:pepboys].nil?
        oreillyauto_engine = m[:oreillyauto].first unless m[:oreillyauto].nil?
        csv_data << [make_value, master_model, master_engine, autozone_model, autozone_engine, advance_auto_model, advance_auto_engine, pepboys_model, pepboys_engine, oreillyauto_model, oreillyauto_engine]
      end
    end
  end
  csv_data
  #csv_data.map(&:to_csv).join
end

def write_file(csv_data,year)
  File.open("#{year}_master_models_data.csv", "w") do |f|
    f.write(csv_data.map(&:to_csv).join)
  end
end

def autozone_target_to_master(year, models, retailer, data, make, match, wd)
  advance_auto_models, autozone_models, oreillyauto_base_models, oreillyauto_models, pepboys_models = load_autoparts_models(advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make)
  models.each do |m|
    model_word_count = m.split.count
    oreillyauto_base_models = []
    oreillyauto_base_models << m.downcase
    engine = autozone_data.select{|d| d if d[3] == m}.map{ |d| d[4]}
    engine.sort_by(&:length).reverse.each do |e|
        @pepboys_engine_match = []
        @autozone_engine_match = []
        @advance_auto_engine_match = []
        @oreillyauto_engine_match = []

      model_data = {}
      e = e.strip
      next if match_exist?(@master_engines[make], retailer, e, m) if match
      next unless (m.downcase.include?('awd') || m.downcase.include?('4wd') || m.downcase.include?('2wd')) if wd
      ocylinder,osize ,otype, ovin = autozone_engine_details(m, e, autozone_data)
      exact_model_match(advance_auto_models, autozone_models, oreillyauto_models, pepboys_models, m.downcase)
      load_autopats_engines(make, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data)
        
        advance_auto_similar_model_match(e, make, oreillyauto_data, m.downcase, advance_auto_models, oreillyauto_base_models, advance_auto_data, false, model_word_count, ocylinder, osize, otype, ovin) if @advance_auto_model.nil?
        advance_auto_similar_model_match(e, make, oreillyauto_data, m.downcase, advance_auto_models, oreillyauto_base_models, advance_auto_data, true, model_word_count, ocylinder, osize, otype, ovin) if @advance_auto_model.nil?
      
        pepboys_similar_model_match(e, make, oreillyauto_data, m.downcase, pepboys_models, oreillyauto_base_models, pepboys_data, false, model_word_count, ocylinder, osize, otype, ovin) if @pepboys_model.nil?
        pepboys_similar_model_match(e, make, oreillyauto_data, m.downcase, pepboys_models, oreillyauto_base_models, pepboys_data, true, model_word_count, ocylinder, osize, otype, ovin) if @pepboys_model.nil?

        oreillyauto_similar_model_match(e, make,  m.downcase, oreillyauto_models, oreillyauto_base_models, oreillyauto_data, false, model_word_count, ocylinder, osize, otype, ovin) if @oreillyauto_model.nil?
        oreillyauto_similar_model_match(e, make,  m.downcase, oreillyauto_models, oreillyauto_base_models, oreillyauto_data, true, model_word_count, ocylinder, osize, otype, ovin) if @oreillyauto_model.nil?

      @master_engines[make][m] ||= {}

      d = {}

      d[:autozone] = e.strip, m
      d[:oreillyauto] = oreillyauto_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
      d[:pepboys] = pepboys_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
      d[:advance_auto] = advance_auto_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
      
      @master_engines[make][m][e] = d
    end
  end
end

def advance_auto_target_to_master(year, models, retailer, data, make)
  advance_auto_models, autozone_models, oreillyauto_base_models, oreillyauto_models, pepboys_models = load_autoparts_models(advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make)
  models.each do |m|
    model_word_count = m.split.count
    oreillyauto_base_models = []
    oreillyauto_base_models << m.downcase
    engine = advance_auto_data.select{|d| d if d[3] == m}.map{ |d| d[4]}
    engine.sort_by(&:length).reverse.each do |e|
        @pepboys_engine_match = []
        @autozone_engine_match = []
        @advance_auto_engine_match = []
        @oreillyauto_engine_match = []
      model_data = {}
      e = e.strip
      next if match_exist?(@master_engines[make], retailer, e, m)
      ocylinder,osize ,otype = advance_auto_engine_details(m, e, advance_auto_data)
      ovin = nil
      exact_model_match(advance_auto_models, autozone_models, oreillyauto_models, pepboys_models, m.downcase)
      load_autopats_engines(make, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data)
        
        autozone_similar_model_match(e, make, oreillyauto_data, m.downcase, autozone_models, oreillyauto_base_models, autozone_data, false, model_word_count, ocylinder, osize, otype, ovin) if @autozone_model.nil?
        autozone_similar_model_match(e, make, oreillyauto_data, m.downcase, autozone_models, oreillyauto_base_models, autozone_data, true, model_word_count, ocylinder, osize, otype, ovin) if @autozone_model.nil?

        pepboys_similar_model_match(e, make, oreillyauto_data, m.downcase, pepboys_models, oreillyauto_base_models, pepboys_data, false, model_word_count, ocylinder, osize, otype, ovin) if @pepboys_model.nil?
        pepboys_similar_model_match(e, make, oreillyauto_data, m.downcase, pepboys_models, oreillyauto_base_models, pepboys_data, true, model_word_count, ocylinder, osize, otype, ovin) if @pepboys_model.nil?

        oreillyauto_similar_model_match(e, make,  m.downcase, oreillyauto_models, oreillyauto_base_models, oreillyauto_data, false, model_word_count, ocylinder, osize, otype, ovin) if @oreillyauto_model.nil?
        oreillyauto_similar_model_match(e, make,  m.downcase, oreillyauto_models, oreillyauto_base_models, oreillyauto_data, true, model_word_count, ocylinder, osize, otype, ovin) if @oreillyauto_model.nil?


      @master_engines[make][m] ||= {}

      d = {}

      d[:advance_auto] = e.strip, m
      d[:oreillyauto] = oreillyauto_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
      d[:pepboys] = pepboys_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
      d[:autozone] = autozone_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)

      @master_engines[make][m][e] = d
    end
  end
end

def pepboys_target_to_master(year, models, retailer, data, make)
  advance_auto_models, autozone_models, oreillyauto_base_models, oreillyauto_models, pepboys_models = load_autoparts_models(advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make)
  models.each do |m|
     model_word_count = m.split.count
    oreillyauto_base_models = []
    oreillyauto_base_models << m.downcase
    engine = pepboys_data.select{|d| d if d[3] == m}.map{ |d| d[4]}
    engine.sort_by(&:length).reverse.each do |e|

      @pepboys_engine_match = []
      @autozone_engine_match = []
      @advance_auto_engine_match = []
      @oreillyauto_engine_match = []
      
      model_data = {}
      e = e.strip
      next if match_exist?(@master_engines[make], retailer, e, m)
      ocylinder,osize ,otype = pepboys_engine_details(m, e, pepboys_data)
      ovin = nil
      exact_model_match(advance_auto_models, autozone_models, oreillyauto_models, pepboys_models, m.downcase)
      load_autopats_engines(make, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data)
        
        autozone_similar_model_match(e, make, oreillyauto_data, m.downcase, autozone_models, oreillyauto_base_models, autozone_data, false, model_word_count, ocylinder, osize, otype, ovin) if @autozone_model.nil?
        autozone_similar_model_match(e, make, oreillyauto_data, m.downcase, autozone_models, oreillyauto_base_models, autozone_data, true, model_word_count, ocylinder, osize, otype, ovin) if @autozone_model.nil?

        advance_auto_similar_model_match(e, make, oreillyauto_data, m.downcase, advance_auto_models, oreillyauto_base_models, advance_auto_data, false, model_word_count, ocylinder, osize, otype, ovin) if @advance_auto_model.nil?
        advance_auto_similar_model_match(e, make, oreillyauto_data, m.downcase, advance_auto_models, oreillyauto_base_models, advance_auto_data, true, model_word_count, ocylinder, osize, otype, ovin) if @advance_auto_model.nil?
        
        oreillyauto_similar_model_match(e, make,  m.downcase, oreillyauto_models, oreillyauto_base_models, oreillyauto_data, false, model_word_count, ocylinder, osize, otype, ovin) if @oreillyauto_model.nil?
        oreillyauto_similar_model_match(e, make,  m.downcase, oreillyauto_models, oreillyauto_base_models, oreillyauto_data, true, model_word_count, ocylinder, osize, otype, ovin) if @oreillyauto_model.nil?


      @master_engines[make][m] ||= {}

      d = {}

      d[:advance_auto] = advance_auto_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
      d[:oreillyauto] = oreillyauto_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
      d[:pepboys] = e.strip, m
      d[:autozone] = autozone_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)

      @master_engines[make][m][e] = d
    end
  end
end

def retailer(csv_data, year)
  new_csv_data = []
  csv_data.each do |t|
    master_engine = t[2]
    row = []
    retailer = ''

    if master_engine.strip == t[4]
      acylinder, asize, atype, avin = autozone_engine_details(t[1], master_engine, autozone_data)
      avin = nil
      retailer = 'autozone'  
    end

    if master_engine.strip == t[6]
      acylinder, asize, atype, avin = advance_auto_engine_details(t[1], master_engine, advance_auto_data)
      retailer = 'advance auto'
    end

    if master_engine.strip == t[8]
      acylinder, asize, atype = pepboys_engine_details(t[1], master_engine, pepboys_data)
      avin = nil
      retailer = 'pepboys'
    end

    if master_engine.strip == t[10]
      acylinder, asize, atype, avin = oreillyauto_engine_details(t[1], master_engine, oreillyauto_data)
    end

    row = t[0..2] + [retailer,asize,acylinder,atype,avin] + t[3..-1]
    new_csv_data << row
  end
  new_csv_data
end

def retailer_wd(csv_data)
  new_csv_data = []
  csv_data.each do |t|
    master_model = t[1]
    master_engine = t[2]
    row = []
    retailer = t[3]
    row << t[8]
      if row.any? { |model| model.include?('AWD') && model.gsub('AWD', '').strip.downcase == master_model.downcase unless model.nil? }
        master_model = t[8]
        master_engine = t[9]
        retailer = '2WD-AWD-4WD'
      elsif row.any? { |model| model.include?('4WD') && model.gsub('4WD', '').strip.downcase == master_model.downcase unless model.nil? }
        master_model = t[8]
        master_engine = t[9]
        retailer = '2WD-AWD-4WD'
      end
      if row.any? { |model| model.include?('2WD') && model.gsub('2WD', '').strip.downcase == master_model.downcase unless model.nil? }
        master_model = t[8]
        master_engine = t[9]
        retailer = '2WD-AWD-4WD'
      end
    t[1] = master_model
    t[2] = master_engine.strip
    t[3] = retailer
    new_csv_data << t
  end
  new_csv_data
end

def sort_models(csv_data)
  new_csv_data = []
  table = csv_data
  makes =  csv_data.map{|t| t[0] }.uniq
  makes.each do |mk|
    mk_data = csv_data.select{|t| t[0] == mk }.uniq
    mk_models =  mk_data.map{ |d| d[1]}.uniq
    new_models = []
    mk_models.each do |m1|
      m =  m1.downcase
      if m.include?('awd') || m.include?('4wd')
        new_m = m.gsub('awd','2wd' ).gsub('4wd', '2wd')
        if new_models.map(&:downcase).include?(new_m)
          new_models.insert(new_models.map(&:downcase).index(new_m), m1)
          next
        end
      end
      new_models << m1 
    end
    
    new_models.each do |m|
      new_csv_data.concat(mk_data.select{|d| d[1] == m})
    end
  end
  new_csv_data
end

def remove_redundant(csv_data)
  sv_data = csv_data
  sv_data.each do |c|
    if (c[4] == 'autozone')
      unless csv_data.select{|d| (d[4] == "" || d[4] == "2WD-AWD-4WD") && (c[1].downcase == d[1].downcase)}.empty? 
      csv_data -= [c]
      end
    end
  end
  csv_data
end

def worker(year)
  @master_engines ={}
  @new_master_engines ={}
  advance_auto_makes, autozone_makes, oreillyauto_makes, pepboys_makes  = load_autoparts_makes(advance_auto_data, autozone_data, oreillyauto_data, pepboys_data)
    makes = (advance_auto_makes | autozone_makes | oreillyauto_makes | pepboys_makes).compact
  makes.map(&:downcase).uniq.each do |make|  
    advance_auto_models, autozone_models, oreillyauto_base_models, oreillyauto_models, pepboys_models = load_autoparts_models(advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make)
    @master_engines[make] ||= {}
    @new_master_engines[make] ||= {}
    oreillyauto_models.map(&:downcase).uniq.each do |m|
      @master_engines[make][m] ||= {}
      @new_master_engines[make][m] ||= {}
      @oreillyauto_model = (@oreillyauto_index = oreillyauto_models.map(&:downcase).index(m)) ? oreillyauto_models[@oreillyauto_index] : nil
      @oreillyauto_engine = oreillyauto_data.select{|d| d if d[1].downcase == make.downcase && d[3] == @oreillyauto_model}.map{ |d| d[6]}
      @oreillyauto_engine.sort_by(&:length).reverse.each do |e|
        @pepboys_engine_match = []
        @autozone_engine_match = []
        @advance_auto_engine_match = []
        @oreillyauto_engine_match = []
      
        @master_engines[make][m][e] ||= {}
        model_word_count = m.split.count
        exact_model_match(advance_auto_models, autozone_models, oreillyauto_models, pepboys_models, m)
        load_autopats_engines(make, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data)
        
        ocylinder, osize, otype, ovin = oreillyauto_engine_details(m, e, oreillyauto_data)
        
        advance_auto_similar_model_match(e, make, oreillyauto_data, m, advance_auto_models, oreillyauto_base_models, advance_auto_data, false, model_word_count, ocylinder, osize, otype, ovin) if @advance_auto_model.nil?
        advance_auto_similar_model_match(e, make, oreillyauto_data, m, advance_auto_models, oreillyauto_base_models, advance_auto_data, true, model_word_count, ocylinder, osize, otype, ovin) if @advance_auto_model.nil?
        
        autozone_similar_model_match(e, make, oreillyauto_data, m, autozone_models, oreillyauto_base_models, autozone_data, false, model_word_count, ocylinder, osize, otype, ovin) if @autozone_model.nil?
        autozone_similar_model_match(e, make, oreillyauto_data, m, autozone_models, oreillyauto_base_models, autozone_data, true, model_word_count, ocylinder, osize, otype, ovin) if @autozone_model.nil?

        pepboys_similar_model_match(e, make, oreillyauto_data, m, pepboys_models, oreillyauto_base_models, pepboys_data, false, model_word_count, ocylinder, osize, otype, ovin) if @pepboys_model.nil?
        pepboys_similar_model_match(e, make, oreillyauto_data, m, pepboys_models, oreillyauto_base_models, pepboys_data, true, model_word_count, ocylinder, osize, otype, ovin) if @pepboys_model.nil?

        d = {}
        d[:oreillyauto] = e.strip, @oreillyauto_model
        d[:pepboys] = pepboys_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
        d[:advance_auto] = advance_auto_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
        d[:autozone] = autozone_engine_mapper(d, e, advance_auto_data, autozone_data, oreillyauto_data, pepboys_data, make, m, ocylinder, osize, otype, ovin)
        @master_engines[make][m][e] = d
      end
    end
    autozone_target_to_master(year, autozone_models, 'autozone', autozone_data, make, true, false)
    #autozone_target_to_master(autozone_models, 'autozone', autozone_data, make, false, true)
    advance_auto_target_to_master(year, advance_auto_models, 'advance_auto', advance_auto_data, make)
    pepboys_target_to_master(year, pepboys_models, 'pepboys', pepboys_data, make)
    target_to_master(advance_auto_models, 'advance_auto', advance_auto_data, make)
    target_to_master(autozone_models, 'autozone', autozone_data, make)
    target_to_master(pepboys_models, 'pepboys', pepboys_data, make)
  end
  write_csv_data(makes, year)
end
end

(2015..2015).each do |y|
  year = y.to_s
  Mapping.new(year)
end