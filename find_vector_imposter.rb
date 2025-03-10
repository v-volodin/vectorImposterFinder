#!/usr/bin/env ruby
# frozen_string_literal: true

# This script finds svg and pdf files containing raster images.

require 'pdf/reader'
require 'rexml/document'
require 'parallel'

module FindVectorImposter
  class PDFInspector
    def does_contain_raster(file)
      PDF::Reader.open(file) do |reader|
        page = reader.page(1)
        xobjects = page.xobjects
        return false if xobjects.empty?

        xobjects.each do |_name, stream|
          case stream.hash[:Subtype]
          when :Image
            return true
          when :Form
            process_page(PDF::Reader::FormXObject.new(page, stream))
          end
        end
        false
      end
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
      puts "Error reading #{file}: #{e.message}"
      false
    end

    def process_page(form_xobject)
      xobjects = form_xobject.xobjects
      return false if xobjects.nil? || xobjects.empty?

      xobjects.each do |_name, stream|
        case stream.hash[:Subtype]
        when :Image
          return true
        when :Form
          return process_page(PDF::Reader::FormXObject.new(form_xobject.page, stream))
        end
      end
      false
    end
  end

  class SVGInspector
    def does_contain_raster(file)
      xml_string = File.read(file)
      doc = REXML::Document.new(xml_string)
      doc.elements.each('//image') do |image_element|
        href = image_element.attributes['href']
        return true if href
      end
      false
    end
  end

  class Finder
    def process_files(files, inspector, file_type, threads)
      return puts "There are no #{file_type.upcase} files in the specified folder." if files.empty?

      vector_imposters_found = 0
      mutex = Mutex.new

      puts "Checking #{file_type} files..."
      Parallel.each(files, in_threads: threads) do |file|
        if inspector.does_contain_raster(file)
          puts File.basename(file)
          mutex.synchronize { vector_imposters_found += 1 }
        end
      end
      puts "#{vector_imposters_found} vector imposters in #{file_type} files found"
    end
  end
end

if ARGV.empty?
  puts 'Specify the path to the folder.'
  exit
end

folder_path = ARGV[0]

unless Dir.exist?(folder_path)
  puts 'The specified folder does not exist.'
  exit
end

pdf_inspector = FindVectorImposter::PDFInspector.new
svg_inspector = FindVectorImposter::SVGInspector.new
pdf_files = Dir.glob(File.join(folder_path, '**', '*.pdf'))
svg_files = Dir.glob(File.join(folder_path, '**', '*.svg'))

puts 'Checking pdf files...'

finder = FindVectorImposter::Finder.new
finder.process_files(pdf_files, pdf_inspector, 'pdf', 4)
finder.process_files(svg_files, svg_inspector, 'svg', 4)