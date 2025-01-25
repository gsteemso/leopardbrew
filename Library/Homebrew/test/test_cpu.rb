require "testing_env"
require 'cpu'

class CPUTests < Homebrew::TestCase
  def test_cpu_type
    assert_includes [:intel, :powerpc], CPU.type
  end

  def test_cpu_arch
    assert_includes [:i386, :ppc, :ppc64, :x86_64], CPU.arch
  end

  def test_cpu_intel_model
    models = [:core, :core2, :penryn, :nehalem, :arrandale, :sandybridge, :ivybridge, :haswell, :broadwell]
    assert_includes models, CPU.model
  end if CPU.intel?
end
