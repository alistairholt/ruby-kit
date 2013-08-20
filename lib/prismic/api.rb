module Prismic
  class Api
    attr_accessor :refs, :bookmarks, :forms, :master, :tags, :types

    def initialize
      @bookmarks = {}
      @refs = {}
      @forms = {}
      @master = nil
      @tags = {}
      @types = {}
      yield self
    end

    def bookmark(name)
      bookmarks[name]
    end

    def ref(name)
      refs[name]
    end

    def form(name)
      forms[name]
    end

    def self.get(url, path = '/api')
      http = Net::HTTP.new(URI(url).host)
      req = Net::HTTP::Get.new(path, {'Accept' => 'application/json'})
      res = http.request(req)

      if res.code == '200'
        res
      else
        raise PrismicWSConnectionError, res.message
      end
    end

    def self.parse_api_response(data)
      new { |api|
        api.bookmarks = data['bookmarks']
        data_forms = data['forms'] || []
        api.forms = Hash[data_forms.map { |k, form|
          [k, SearchForm.new(api, Form.new(
            form['name'],
            Hash[form['fields'].map { |k2, field|
              [k2, Field.new(field['type'], field['default'])]
            }],
            form['method'],
            form['rel'],
            form['enctype'],
            form['action'],
          ))]
        }]
        data_refs = data.fetch('refs'){ raise BadPrismicResponseError, "No refs given" }
        api.refs = Hash[data_refs.map { |ref|
          [ref['label'], Ref.new(ref['ref'], ref['label'], ref['isMasterRef'])]
        }]
        api.master = api.refs.values.map { |ref| ref if ref.master? }.compact.first
        raise BadPrismicResponseError, "No master Ref found" unless api.master
        api.tags = data['tags']
        api.types = data['types']
      }
    end

    private

    class BadPrismicResponseError < Error ; end

    class PrismicWSConnectionError < Error
      def initialize(msg, cause=nil)
        super("Can't connect to Prismic's API: #{msg}", cause)
      end
    end
  end
end