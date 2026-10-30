namespace Claims.Api.Domain;

/// <summary>
/// Pravidla reklamací podle českého spotřebitelského práva (zjednodušeno pro demo).
/// </summary>
public static class ClaimPolicy
{
    /// <summary>Zákonná lhůta pro vyřízení reklamace.</summary>
    public const int ResolutionDays = 30;

    /// <summary>Zákonná záruka pro spotřebitele.</summary>
    public const int WarrantyMonths = 24;

    public static DateOnly ResolutionDeadline(DateOnly receivedOn) =>
        receivedOn.AddDays(ResolutionDays);

    public static bool IsWithinWarranty(DateOnly purchasedOn, DateOnly claimedOn)
    {
        if (claimedOn < purchasedOn)
        {
            throw new ArgumentException("Reklamace nemůže předcházet nákupu.", nameof(claimedOn));
        }

        return claimedOn <= purchasedOn.AddMonths(WarrantyMonths);
    }
}
