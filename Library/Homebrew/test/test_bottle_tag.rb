require "testing_env"
require "bottles"

class BottleTagTests < Homebrew::TestCase
  def test_tag_tiger_ppc
    MacOS.stubs(:version).returns(MacOS::Version.new("10.4"))
    CPU.stubs(:type).returns(:powerpc)
    CPU.stubs(:model).returns(:foo)
    Target.stubs(:prefer_64b?).returns(false)
    assert_equal :tiger_foo, bottle_tag
  end

  def test_tag_tiger_intel
    MacOS.stubs(:version).returns(MacOS::Version.new("10.4"))
    CPU.stubs(:type).returns(:intel)
    Target.stubs(:prefer_64b?).returns(false)
    assert_equal :tiger, bottle_tag
  end

  def test_tag_tiger_ppc_64
    MacOS.stubs(:version).returns(MacOS::Version.new("10.4"))
    CPU.stubs(:type).returns(:powerpc)
    CPU.stubs(:model).returns(:g5)
    Target.stubs(:prefer_64b?).returns(true)
    assert_equal :tiger_g5_64, bottle_tag
  end

  # Note that this will probably never be used
  def test_tag_tiger_intel_64
    MacOS.stubs(:version).returns(MacOS::Version.new("10.4"))
    CPU.stubs(:type).returns(:intel)
    Target.stubs(:prefer_64b?).returns(true)
    assert_equal :tiger_64, bottle_tag
  end

  def test_tag_leopard_intel
    MacOS.stubs(:version).returns(MacOS::Version.new("10.5"))
    CPU.stubs(:type).returns(:intel)
    Target.stubs(:prefer_64b?).returns(false)
    assert_equal :leopard, bottle_tag
  end

  def test_tag_leopard_ppc_64
    MacOS.stubs(:version).returns(MacOS::Version.new("10.5"))
    CPU.stubs(:type).returns(:powerpc)
    CPU.stubs(:model).returns(:g5)
    Target.stubs(:prefer_64b?).returns(true)
    assert_equal :leopard_g5_64, bottle_tag
  end

  def test_tag_leopard_intel_64
    MacOS.stubs(:version).returns(MacOS::Version.new("10.5"))
    CPU.stubs(:type).returns(:intel)
    Target.stubs(:prefer_64b?).returns(true)
    assert_equal :leopard_64, bottle_tag
  end

  def test_tag_snow_leopard_32
    MacOS.stubs(:version).returns(MacOS::Version.new("10.6"))
    CPU.stubs(:_64b?).returns(false)
    assert_equal :snow_leopard_32, bottle_tag
  end

  def test_tag_snow_leopard_64
    MacOS.stubs(:version).returns(MacOS::Version.new("10.6"))
    CPU.stubs(:_64b?).returns(true)
    assert_equal :snow_leopard, bottle_tag
  end

  def test_tag_lion
    MacOS.stubs(:version).returns(MacOS::Version.new("10.7"))
    assert_equal :lion, bottle_tag
  end

  def test_tag_mountain_lion
    MacOS.stubs(:version).returns(MacOS::Version.new("10.8"))
    assert_equal :mountain_lion, bottle_tag
  end
end
