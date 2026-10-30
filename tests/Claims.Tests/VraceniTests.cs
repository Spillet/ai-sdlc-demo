using Claims.Api.Refunds;

namespace Claims.Tests;

public class VraceniTests
{
    [Fact]
    public void Regular_discount_is_applied()
    {
        Assert.Equal(300m, Vraceni.CastkaKVraceni(1000m, 0.3m));
    }

    [Theory]
    [InlineData(0.0, 0.0)]
    [InlineData(0.5, 500.0)]
    [InlineData(0.8, 500.0)]
    [InlineData(-0.2, 0.0)]
    public void Boundary_rates(double rate, double expected)
    {
        Assert.Equal((decimal)expected, Vraceni.CastkaKVraceni(1000m, (decimal)rate));
    }

    [Fact]
    public void Result_is_rounded_to_hellers()
    {
        var result = Vraceni.CastkaKVraceni(99.99m, 0.333m);

        Assert.Equal(33.30m, result);
        Assert.Equal(result, decimal.Round(result, 2));
    }

    [Theory]
    [InlineData(1999.90, 0.25)]
    [InlineData(10, 0.9)]
    [InlineData(0.01, 0.5)]
    public void Matches_refund_calculator(double price, double rate)
    {
        Assert.Equal(
            RefundCalculator.Calculate((decimal)price, ClaimOutcome.PartialRefund, (decimal)rate),
            Vraceni.CastkaKVraceni((decimal)price, (decimal)rate));
    }

    [Fact]
    public void Negative_price_is_rejected()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => Vraceni.CastkaKVraceni(-1m, 0.2m));
    }
}
