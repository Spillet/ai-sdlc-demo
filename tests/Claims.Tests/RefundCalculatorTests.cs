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
    public void Partial_refund_above_cap_is_capped_at_60_percent_of_price()
    {
        Assert.Equal(600m, RefundCalculator.Calculate(1000m, ClaimOutcome.PartialRefund, 0.8m));
    }

    [Fact]
    public void Partial_refund_exactly_at_cap_is_60_percent_of_price()
    {
        Assert.Equal(0.6m, RefundCalculator.MaxPartialRefundRate);
        Assert.Equal(600m, RefundCalculator.Calculate(1000m, ClaimOutcome.PartialRefund, 0.6m));
    }

    [Fact]
    public void Partial_refund_below_cap_is_unchanged()
    {
        Assert.Equal(500m, RefundCalculator.Calculate(1000m, ClaimOutcome.PartialRefund, 0.5m));
    }

    [Fact]
    public void Negative_price_is_rejected()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => RefundCalculator.Calculate(-1m, ClaimOutcome.FullRefund));
    }
}
