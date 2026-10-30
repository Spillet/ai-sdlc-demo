using Claims.Api.Domain;

namespace Claims.Tests;

public class ClaimPolicyTests
{
    [Fact]
    public void Deadline_is_30_days_after_receipt()
    {
        var deadline = ClaimPolicy.ResolutionDeadline(new DateOnly(2026, 11, 1));

        Assert.Equal(new DateOnly(2026, 12, 1), deadline);
    }

    [Theory]
    [InlineData("2025-01-15", "2027-01-15", true)]
    [InlineData("2025-01-15", "2027-01-16", false)]
    [InlineData("2026-10-30", "2026-10-30", true)]
    public void Warranty_is_24_months(string purchased, string claimed, bool expected)
    {
        var result = ClaimPolicy.IsWithinWarranty(DateOnly.Parse(purchased), DateOnly.Parse(claimed));

        Assert.Equal(expected, result);
    }

    [Theory]
    [InlineData("2026-10-01", "2026-10-01", 30)]
    [InlineData("2026-10-01", "2026-10-11", 20)]
    [InlineData("2026-10-01", "2026-10-31", 0)]
    [InlineData("2026-10-01", "2026-11-01", -1)]
    public void Remaining_days_counts_to_deadline(string received, string today, int expected)
    {
        var result = ClaimPolicy.RemainingDays(DateOnly.Parse(received), DateOnly.Parse(today));

        Assert.Equal(expected, result);
    }

    [Fact]
    public void Remaining_days_before_receipt_is_rejected()
    {
        Assert.Throws<ArgumentException>(() =>
            ClaimPolicy.RemainingDays(new DateOnly(2026, 10, 2), new DateOnly(2026, 10, 1)));
    }

    [Fact]
    public void Claim_before_purchase_is_rejected()
    {
        Assert.Throws<ArgumentException>(() =>
            ClaimPolicy.IsWithinWarranty(new DateOnly(2026, 5, 1), new DateOnly(2026, 4, 30)));
    }
}
