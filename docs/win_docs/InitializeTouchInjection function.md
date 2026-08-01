---
layout: Conceptual
title: InitializeTouchInjection function (winuser.h) - Win32 apps | Microsoft Learn
canonicalUrl: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-initializetouchinjection
adobe-target: true
breadcrumb_path: /windows/desktop/api/breadcrumb/toc.json
uhfHeaderId: MSDocsHeader-WinDevCenter
ms.service: windows-api-desktop-tech
ms.subservice: sdk-api-reference
ms.topic: reference
ms.author: jimwalk
author: jwmsft
feedback_system: Standard
feedback_product_url: https://www.microsoft.com/en-us/windowsinsider/feedbackhub/fb
feedback_help_link_url: https://learn.microsoft.com/answers/tags/224/windows-api-win32/
feedback_help_link_type: get-help-at-qna
UID: NF:winuser.InitializeTouchInjection
description: Configures the touch injection context for the calling application and initializes the maximum number of simultaneous contacts that the app can inject.
old-location: input_touchinjection\initializetouchinjection.htm
tech.root: controls
ms.assetid: 79cc2a05-d8ee-4d87-9c7b-fa7d5354b04f
ms.date: 2018-12-05T00:00:00.0000000Z
ms.keywords: InitializeTouchInjection, InitializeTouchInjection function [Windows Touch], input_touchinjection.initializetouchinjection, touch_injection.initializetouchinjection, winuser/InitializeTouchInjection
req.header: winuser.h
req.include-header: 
req.target-type: Windows
req.target-min-winverclnt: Windows 8 [desktop apps only]
req.target-min-winversvr: Windows Server 2012 [desktop apps only]
req.kmdf-ver: 
req.umdf-ver: 
req.ddi-compliance: 
req.unicode-ansi: 
req.idl: 
req.max-support: 
req.namespace: 
req.assembly: 
req.type-library: 
req.lib: User32.lib
req.dll: User32.dll
req.irql: 
targetos: Windows
req.typenames: 
req.redist: 
ms.custom: 19H1
topic_type:
- APIRef
- kbSyntax
api_type:
- DllExport
api_location:
- ext-ms-win-rtcore-ntuser-wmpointermin-l1-1-0.dll
- api-ms-win-rtcore-ntuser-wmpointer-l1-2-0.dll
- user32.dll
- API-MS-Win-RTCore-NTUser-WMPointer-l1-1-0.dll
- MinUser.dll
- API-MS-Win-RTCore-NTUser-WMPointer-l1-1-1.dll
- API-Ms-Win-RTCore-NTUser-WMPointer-L1-1-2.dll
- API-MS-Win-RTCore-NTUser-WMPointer-L1-1-3.dll
api_name:
- InitializeTouchInjection
req.apiset: ext-ms-win-rtcore-ntuser-wmpointer-l1-1-0 (introduced in Windows 10, version 10.0.14393)
locale: en-us
document_id: d8fdbef5-8419-af64-5e72-3baef013c983
document_version_independent_id: bc583fd4-3242-b329-74fd-f23e5e1ffdfc
updated_at: 2025-07-01T18:41:00.0000000Z
original_content_git_url: https://cpubwin.visualstudio.com/DefaultCollection/win32/_git/sdk-api-build?path=/sdk-api-src/content/winuser/nf-winuser-initializetouchinjection.md&version=GBlive&_a=contents
gitcommit: https://cpubwin.visualstudio.com/DefaultCollection/win32/_git/sdk-api-build/commit/fa53641576e3603fa7b66d3a4ad969d3ce49d6f3?path=/sdk-api-src/content/winuser/nf-winuser-initializetouchinjection.md&_a=contents
git_commit_id: fa53641576e3603fa7b66d3a4ad969d3ce49d6f3
site_name: Docs
depot_name: MSDN.sdk-api-build
page_type: conceptual
toc_rel: ../_controls/toc.json
pdf_url_template: https://learn.microsoft.com/pdfstore/en-us/MSDN.sdk-api-build/{branchName}{pdfName}
search.mshattr.devlang: c++
word_count: 210
asset_id: winuser/nf-winuser-initializetouchinjection
moniker_range_name: 
monikers: []
item_type: Content
source_path: sdk-api-src/content/winuser/nf-winuser-initializetouchinjection.md
cmProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/caec7b7f-4941-4578-b79f-c63b1c1f5af4
- https://authoring-docs-microsoft.poolparty.biz/devrel/540ac133-a371-4dbb-8f94-28d6cc77a70b
- https://authoring-docs-microsoft.poolparty.biz/devrel/bcbcbad5-4208-4783-8035-8481272c98b8
spProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/754dea88-f800-4835-b6b5-280cb5d81e88
- https://authoring-docs-microsoft.poolparty.biz/devrel/60bfc045-f127-4841-9d00-ea35495a5800
- https://authoring-docs-microsoft.poolparty.biz/devrel/43b2e5aa-8a6d-4de2-a252-692232e5edc8
platformId: 3b9ea040-d444-316b-566f-155363ba74d3
---

# InitializeTouchInjection function (winuser.h) - Win32 apps | Microsoft Learn

Configures the touch injection context for the calling application and initializes the maximum number of simultaneous contacts that the app can inject.
**Note** **InitializeTouchInjection** must precede any call to [InjectTouchInput](/en-us/windows/desktop/api/winuser/nf-winuser-injecttouchinput).
## Syntax

```cpp
BOOL InitializeTouchInjection(
  [in] UINT32 maxCount,
  [in] DWORD  dwMode
);
```

## Parameters

`[in] maxCount`

The maximum number of touch contacts.

The *maxCount* parameter must be greater than 0 and less than or equal to MAX\_TOUCH\_COUNT (256) as defined in winuser.h.

`[in] dwMode`

The contact visualization mode.

The *dwMode* parameter must be [TOUCH_FEEDBACK_DEFAULT](/en-us/previous-versions/windows/desktop/input_touchinjection/constants), **TOUCH\_FEEDBACK\_INDIRECT**, or **TOUCH\_FEEDBACK\_NONE**.

## Return value

If the function succeeds, the return value is TRUE.

If the function fails, the return value is FALSE. To get extended error information, call [GetLastError](/en-us/windows/desktop/api/errhandlingapi/nf-errhandlingapi-getlasterror).

## Remarks

If [TOUCH_FEEDBACK_DEFAULT](/en-us/previous-versions/windows/desktop/input_touchinjection/constants) is set, the injected touch feedback may get suppressed by the end-user settings in the **Pen and Touch** control panel.

If [TOUCH_FEEDBACK_INDIRECT](/en-us/previous-versions/windows/desktop/input_touchinjection/constants) is set, the injected touch feedback overrides the end-user settings in the **Pen and Touch** control panel.

If [TOUCH_FEEDBACK_INDIRECT](/en-us/previous-versions/windows/desktop/input_touchinjection/constants) or **TOUCH\_FEEDBACK\_NONE** are set, touch feedback provided by applications and controls may not be affected.

## Requirements

| Requirement | Value |
| --- | --- |
| **Minimum supported client** | Windows 8 [desktop apps only] |
| **Minimum supported server** | Windows Server 2012 [desktop apps only] |
| **Target Platform** | Windows |
| **Header** | winuser.h |
| **Library** | User32.lib |
| **DLL** | User32.dll |
| **API set** | ext-ms-win-rtcore-ntuser-wmpointer-l1-1-0 (introduced in Windows 10, version 10.0.14393) |