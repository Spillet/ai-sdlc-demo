namespace Claims.Api.Refunds;

public enum ClaimOutcome
{
    Rejected,
    Repaired,
    PartialRefund,
    FullRefund,
}

/// <summary>
/// Výpočet vrácené částky po vyřízení reklamace. Citlivá oblast: peníze zákazníků.
/// </summary>
public static class RefundCalculator
{
    /// <summary>Nejvyšší sleva z ceny při přiměřené slevě (sleva místo opravy).</summary>
    public const decimal MaxPartialRefundRate = 0.5m;

    public static decimal Calculate(decimal price, ClaimOutcome outcome, decimal partialRate = 0m)
    {
        if (price < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(price), "Cena nemůže být záporná.");
        }

        return outcome switch
        {
            ClaimOutcome.Rejected => 0m,
            ClaimOutcome.Repaired => 0m,
            ClaimOutcome.FullRefund => price,
            ClaimOutcome.PartialRefund => Math.Round(price * Math.Clamp(partialRate, 0m, MaxPartialRefundRate), 2),
            _ => throw new ArgumentOutOfRangeException(nameof(outcome)),
        };
    }
}
