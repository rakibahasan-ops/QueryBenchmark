using Microsoft.AspNetCore.Mvc;

namespace QueryBenchmark.Controllers;

public class HomeController : Controller
{
    public IActionResult Index() => View();
}