require "options"

module Dependable
  RESERVED_TAGS = [:build, :optional, :recommended, :run]

  def build?; tags.include? :build; end

  def optional?; tags.include? :optional; end

  def recommended?; tags.include? :recommended; end

  def run?; tags.include? :run; end

  def required?; run? || (!build? && !optional? && !recommended?); end

  def options; Options.create(tags - RESERVED_TAGS); end

  def build_optional?; build? && optional?; end

  def build_recommended?; build? && recommended?; end

  def build_required?; build? && !optional? && !recommended? ; end

  def run_optional?; !build? && optional?; end

  def run_recommended?; !build? && recommended?; end
end # Dependable
