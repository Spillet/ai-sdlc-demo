using Claims.Api.Refunds;

namespace Claims.Tests;

public class RefundCalculatorTests
{
    [Theory]
    [InlineData(ClaimOutcome.Rejected, 0.0)]
    [InlineData(ClaimOutcome.Repaired, 0.0)]
    [InlineData(ClaimOutcome.FullRefund, 1999.90)]
    public void Refund_by_outcome(ClaimOutcome outcome, double expected)
    {
        Assert.Equal((decimal)expected, RefundCalculator.Calculate(1999.90m, outcome));
    }

    [Fact]
    public void Partial_refund_is_capped_at_half_of_price()
    {
        Assert.Equal(500m, RefundCalculator.Calculate(1000m, ClaimOutcome.PartialRefund, 0.8m));
    }

    [Fact]
    public void Negative_price_is_rejected()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => RefundCalculator.Calculate(-1m, ClaimOutcome.FullRefund));
    }
}
