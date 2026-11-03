namespace Claims.Api.Content.Templates;

public sealed class ClaimPeakDelayTemplate : IMessageTemplate
{
    public string Key => "claim-peak-delay";
    public string Subject => "Reklamace {claimNumber}: v sezóně to potrvá déle";
    public string Body =>
        "Dobrý den, reklamaci {claimNumber} k objednávce {orderNumber} jsme přijali. V sezóně Black Friday máme víc práce, vyřídíme ji ale v zákonné lhůtě, nejpozději do {resolveBy}.";
}
