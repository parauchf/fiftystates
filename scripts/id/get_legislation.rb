#!/usr/bin/ruby


require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'memoize'

$year=2009
STATE='ID'
CHAMBER_LKUP={ 'S'=>'upper',
               'H'=>'lower'}

$fBill  = File.new("bill.csv", File::CREAT|File::RDWR)
$fVersions  = File.new("bill_version.csv", File::CREAT|File::RDWR)
$fSponsors  = File.new("sponsorship.csv", File::CREAT|File::RDWR)
$fActions  = File.new("action.csv", File::CREAT|File::RDWR)

def parse_sponsors(sponsor_text)
   sponsors=[]
   sponsor_text=$1 if sponsor_text =~ /by (.*)/
   if (sponsor_text =~ /\bCOMMITTEE\b/)
      sponsors=['"'+sponsor_text+'"'];
   else
      sponsors=sponsor_text.split(/\bAND\b|,/).
         each{|name| name.strip!}.
         select{|name| "" != name}
   end
   return sponsors
end

def parse_actions(action_docs)
   actions=[]
   action_docs.select{|tr| (tr/'td[2]').inner_text =~ %r!\d{2}/\d{2}!}.each do |tr|
      date = (tr/'td[2]').inner_text.strip + "/#{$year}"
      event_text = (tr/'td[3]').inner_text
      actions.push({ :date=>date,
                     :event=>event_text})
   end
   return actions
end

def parse_versions(bill_doc)
   versions=[]
   (bill_doc/'a').select{|a| a['id'] =~ /^(H|S)\d{4}(E\d)?$/}.each do |a|
      version=a.inner_text
      text_link="http://www.legislature.idaho.gov/legislation/#{$year}/"+a['href']
      versions.push({ :version=>version,
                      :link=>text_link})
   end
   return versions
end

def scrape_bill_page(url,bill_id,chamber)
   open(url) do |bill_page|
   
      #gsub is a hack to eliminate malformed comments
      bill_doc = Hpricot.parse(bill_page.read.gsub!(/\<\s*![^\>]{0,200}?\>/,''))
   
      #get bill versoins
      versions=parse_versions(bill_doc)
      versions.each do |version|
          $fVersions.puts [
         STATE, 
         bill_id, 
         chamber, 
         $year, 
         version[:version], 
         version[:link]
          ].join(',')
      end
      
      #get and parse the sponsor(s)
      csspath='html>body>table>tr>td[2]>table[1]>tr>td[3]'
      sponsors=parse_sponsors((bill_doc/csspath).inner_html)
      sponsors.each do |sponsor|
         $fSponsors.puts [ 
         STATE, 
         bill_id, 
         chamber, 
         $year, 
         '', 
         sponsor
         ].join(',') 
      end
      
      #get the action history and parse it
      csspath='html>body>table>tr>td[2]>table[3]>tr'
      actions=parse_actions(bill_doc/csspath)
      actions.each do |action|
         $fActions.puts [
         STATE, 
         bill_id, 
         chamber, 
         $year, 
         action[:event], 
         action[:date], 
         ].join(',')
      end
   end
end

#main script
open( "http://www.legislature.idaho.gov/"+
      "legislation/#{$year}/minidata.htm") do |page|

   doc = Hpricot.parse(page.read)
   #get all the tr's that have the right kind of id
   (doc/'tr').select{|tr| tr['id'] =~ /bill(H|S)\d{4}/}.each do |tr|
      
      #trim the 'a' from the bill id's 
      bill_id=$1 if ((tr/'td')[0].inner_text)=~/((H|S)\d{4})/
      chamber = CHAMBER_LKUP[$2]
      link='http://www.legislature.idaho.gov'+
            (tr/'td/a').first['href'].to_s
      title='"'+(tr/'td')[1].inner_text.strip+'"'

      #output main bill file
      $fBill.puts [STATE, chamber, $year, bill_id, title].join(',')
      #scrape the individual bill page
      scrape_bill_page(link,bill_id,chamber)
      
   end
end

