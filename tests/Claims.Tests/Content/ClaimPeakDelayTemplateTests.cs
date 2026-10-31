using Claims.Api.Content;

namespace Claims.Tests.Content;

public class ClaimPeakDelayTemplateTests
{
    [Fact]
    public void Template_is_registered_and_fills_placeholders()
    {
        var template = MessageCatalog.Find("claim-peak-delay");
        Assert.NotNull(template);

        var message = MessageCatalog.Render(template, new Dictionary<string, string>
        {
            ["orderNumber"] = "2026-1001",
            ["claimNumber"] = "R-17",
            ["resolveBy"] = "30. 11. 2026",
        });

        Assert.Contains("R-17", message.Subject + message.Body);
        Assert.DoesNotContain("{", message.Subject + message.Body);
    }
}
