namespace Claims.Api.Refunds;

/// <summary>
/// Pomocná třída pro zákaznickou podporu: částka k vrácení při uznané slevě.
/// Pravidla (limit slevy) se neduplikují, výpočet deleguje na <see cref="RefundCalculator"/>.
/// </summary>
public static class Vraceni
{
    /// <summary>Částka k vrácení z ceny a uznané slevy (podíl z ceny 0–1), zaokrouhlená na haléře.</summary>
    public static decimal CastkaKVraceni(decimal price, decimal partialRate)
    {
        return Math.Round(RefundCalculator.Calculate(price, ClaimOutcome.PartialRefund, partialRate), 2);
    }
}
