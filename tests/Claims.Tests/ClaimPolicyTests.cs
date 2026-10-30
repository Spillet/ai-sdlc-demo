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

    [Fact]
    public void Claim_before_purchase_is_rejected()
    {
        Assert.Throws<ArgumentException>(() =>
            ClaimPolicy.IsWithinWarranty(new DateOnly(2026, 5, 1), new DateOnly(2026, 4, 30)));
    }
}
