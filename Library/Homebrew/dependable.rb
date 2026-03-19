require 'options'  # pulls in 'set'

module Dependable
  attr_reader :name, :tags

  RESERVED_TAGS = [:build, :optional, :recommended, :run]

  def build?; tags.include? :build; end

  def optional?; tags.include? :optional; end

  def recommended?; tags.include? :recommended; end

  def run?; tags.include? :run; end


  def discretionary?; optional? or recommended?; end


  def build_optional?; build? and optional?; end

  def build_recommended?; build? and recommended?; end

  def build_required?; build? and not discretionary? ; end

  def required?; run? or not (build? or discretionary?); end

  def run_optional?; not build? and optional?; end

  def run_recommended?; not build? and recommended?; end


  def options; Options.create(unreserved_tags); end

  def unreserved_tags; tags - RESERVED_TAGS; end
end # Dependable
