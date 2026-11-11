import QtQuick
import QtTest
import "../../Common/functions/LaunchpadLayout.js" as LaunchpadLayout

TestCase {
    name: "LaunchpadLayout"

    function test_removeApplicationDoesNotLeaveHiddenTombstone() {
        const layout = {
            items: [
                {
                    type: "app",
                    id: "org.example.Editor"
                },
                {
                    type: "folder",
                    id: "folder-tools",
                    name: "Tools",
                    items: [
                        {
                            type: "app",
                            id: "org.example.Terminal"
                        },
                        {
                            type: "app",
                            id: "org.example.Viewer"
                        }
                    ]
                }
            ],
            hidden: ["org.example.Editor", "org.example.Terminal"]
        };

        const next = LaunchpadLayout.removeApplication(layout, "org.example.Terminal");
        compare(next.items.length, 2);
        compare(next.items[1].type, "app");
        compare(next.items[1].id, "org.example.Viewer");
        compare(next.hidden.join(","), "org.example.Editor");
        compare(layout.items[1].items.length, 2);
    }

    function test_removeLastFolderApplicationCollapsesFolder() {
        const layout = {
            items: [
                {
                    type: "folder",
                    id: "folder-one",
                    name: "One",
                    items: [
                        {
                            type: "app",
                            id: "org.example.Only"
                        }
                    ]
                }
            ],
            hidden: []
        };

        const next = LaunchpadLayout.removeApplication(layout, "org.example.Only");
        compare(next.items.length, 0);
    }

    function test_releaseFromFolderKeepsApplicationInLayout() {
        const layout = {
            items: [
                {
                    type: "app",
                    id: "org.example.Editor"
                },
                {
                    type: "folder",
                    id: "folder-tools",
                    name: "Tools",
                    items: [
                        {
                            type: "app",
                            id: "org.example.Terminal"
                        },
                        {
                            type: "app",
                            id: "org.example.Viewer"
                        },
                        {
                            type: "app",
                            id: "org.example.Files"
                        }
                    ]
                }
            ],
            hidden: []
        };

        const next = LaunchpadLayout.releaseFromFolder(layout, "folder-tools", "org.example.Viewer");
        compare(next.items.length, 3);
        compare(next.items[1].type, "folder");
        compare(next.items[1].items.length, 2);
        compare(next.items[2].type, "app");
        compare(next.items[2].id, "org.example.Viewer");
    }

    function test_releaseLastFolderApplicationDissolvesFolder() {
        const layout = {
            items: [
                {
                    type: "folder",
                    id: "folder-one",
                    name: "One",
                    items: [
                        {
                            type: "app",
                            id: "org.example.Only"
                        }
                    ]
                }
            ],
            hidden: []
        };

        const next = LaunchpadLayout.releaseFromFolder(layout, "folder-one", "org.example.Only");
        compare(next.items.length, 1);
        compare(next.items[0].type, "app");
        compare(next.items[0].id, "org.example.Only");
    }
}
