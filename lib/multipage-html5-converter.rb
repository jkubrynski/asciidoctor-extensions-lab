require 'asciidoctor'

# Chunks the HTML output generated by the HTML5 converter by chapter.
#
# Usage
#
#   asciidoctor -r ./multipage-html5-converter.rb -b multipage_html5 book.adoc
#
# TODO
# * fix xrefs that span chapters
class MultipageHtml5Converter
  include Asciidoctor::Converter
  include Asciidoctor::Writer

  register_for 'multipage_html5'

  EOL = "\n"

  def initialize backend, opts
    super
    basebackend 'html'
    @documents = []
  end

  def convert node, transform = nil
    transform ||= node.node_name
    send transform, node if respond_to? transform
  end

  def document node
    node.blocks.each {|b| b.convert }
    node.blocks.clear
    master_content = []
    master_content << %(= #{node.doctitle})
    master_content << (node.attr 'author') if node.attr? 'author'
    master_content << ''
    @documents.each do |doc|
      sect = doc.blocks[0]
      sectnum = sect.numbered && !sect.caption ? %(#{sect.sectnum} ) : nil
      master_content << %(* <<#{doc.attr 'docname'}#,#{sectnum}#{sect.captioned_title}>>)
    end
    Asciidoctor.convert master_content, :doctype => node.doctype, :header_footer => true, :safe => node.safe
  end

  def section node
    doc = node.document
    page = Asciidoctor::Document.new [], :header_footer => true, :doctype => doc.doctype, :safe => doc.safe, :parse => true, :attributes => { 'noheader' => '', 'doctitle' => node.title }
    page.set_attr 'docname', node.id
    # TODO recurse
    #node.parent = page
    #node.blocks.each {|b| b.parent = node }
    reparent node, page

    # NOTE don't use << on page since it changes section number
    page.blocks << node
    @documents << page
    ''
  end

  def reparent node, parent
    node.parent = parent
    node.blocks.each do |block|
      reparent block, node unless block.context == :dlist
      if block.context == :table
        block.columns.each do |col|
          col.parent = col.parent
        end
        block.rows.body.each do |row|
          row.each do |cell|
            cell.parent = cell.parent
          end
        end
      end
    end
  end

  #def paragraph node
  #  puts 'here'
  #end

  def write output, target
    outdir = ::File.dirname target
    @documents.each do |doc|
      outfile = ::File.join outdir, %(#{doc.attr 'docname'}.html)
      ::File.open(outfile, 'w') do |f|
        f.write doc.convert
      end
    end
    chunked_target = target.gsub(/(\.[^.]+)$/, '-chunked\1')
    ::File.open(chunked_target, 'w') do |f|
      f.write output
    end
  end
end
