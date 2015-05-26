module ProductsHelper
	def pad_read_hash(date_hash, days_ago=7)
		date_hash = {} if date_hash.nil? or !date_hash.is_a?(Hash)
		if date_hash.first and Date.parse(date_hash.first[0]) < Date.today-days_ago
			start_date = Date.parse(date_hash.first[0])
		else
			start_date = Date.today-days_ago
		end
		check_date = start_date
		today = Date.today
		while check_date.to_s != today.to_s
			_date = check_date.to_s
			date_hash[_date] = 0 unless date_hash.has_key? _date
			check_date = check_date + 1
		end
		new_hash={}
		date_hash.sort.map{|k,v| new_hash[k]=v}
		return new_hash
	end

	def get_read_graph(read_count)
		read_count = pad_read_hash(read_count)
		line_chart read_count, width:'50px', height:'25px', library: {height:25, width:50, curveType: 'none', pointSize: 0, chartArea:{left:0,top:0,width:50,height:25}, crosshair: {opacity: 0}, enableInteractivity: false, vAxis:{textPosition:'none', gridlines:{count:0}}, hAxis:{textPosition: 'none'}}
	end
end
