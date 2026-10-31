using Claims.Api.Content;

namespace Claims.Tests.Content;

public class ClaimCourierPickupTemplateTests
{
    [Fact]
    public void Template_is_registered_and_fills_placeholders()
    {
        var template = MessageCatalog.Find("claim-courier-pickup");
        Assert.NotNull(template);

        var message = MessageCatalog.Render(template, new Dictionary<string, string>
        {
            ["orderNumber"] = "2026-1001",
            ["claimNumber"] = "R-17",
            ["resolveBy"] = "30. 11. 2026",
        });

        Assert.Contains("R-17", message.Subject);
        Assert.Contains("kurýr", message.Subject);
        Assert.Contains("R-17", message.Body);
        Assert.Contains("2026-1001", message.Body);
        Assert.Contains("30. 11. 2026", message.Body);
        Assert.DoesNotContain("{", message.Subject);
        Assert.DoesNotContain("{", message.Body);
    }
}
