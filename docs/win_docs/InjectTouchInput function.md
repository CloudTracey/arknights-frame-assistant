---
layout: Conceptual
title: InjectTouchInput function (winuser.h) - Win32 apps | Microsoft Learn
canonicalUrl: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-injecttouchinput
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
UID: NF:winuser.InjectTouchInput
description: Simulates touch input.
old-location: input_touchinjection\injecttouchinput.htm
tech.root: controls
ms.assetid: c3c1425e-2af6-4ecb-a0b2-a456654f7a53
ms.date: 2018-12-05T00:00:00.0000000Z
ms.keywords: InjectTouchInput, InjectTouchInput function [Windows Touch], input_touchinjection.injecttouchinput, touch_injection.injecttouchinput, winuser/InjectTouchInput
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
- InjectTouchInput
req.apiset: ext-ms-win-rtcore-ntuser-wmpointer-l1-1-0 (introduced in Windows 10, version 10.0.14393)
locale: en-us
document_id: 91139ae2-58da-3bf8-d834-675ef5d8da89
document_version_independent_id: 4811761f-7630-5adc-b882-524c1251fcd1
updated_at: 2025-07-01T18:41:00.0000000Z
original_content_git_url: https://cpubwin.visualstudio.com/DefaultCollection/win32/_git/sdk-api-build?path=/sdk-api-src/content/winuser/nf-winuser-injecttouchinput.md&version=GBlive&_a=contents
gitcommit: https://cpubwin.visualstudio.com/DefaultCollection/win32/_git/sdk-api-build/commit/fa53641576e3603fa7b66d3a4ad969d3ce49d6f3?path=/sdk-api-src/content/winuser/nf-winuser-injecttouchinput.md&_a=contents
git_commit_id: fa53641576e3603fa7b66d3a4ad969d3ce49d6f3
site_name: Docs
depot_name: MSDN.sdk-api-build
page_type: conceptual
toc_rel: ../_controls/toc.json
pdf_url_template: https://learn.microsoft.com/pdfstore/en-us/MSDN.sdk-api-build/{branchName}{pdfName}
search.mshattr.devlang: c++
word_count: 761
asset_id: winuser/nf-winuser-injecttouchinput
moniker_range_name: 
monikers: []
item_type: Content
source_path: sdk-api-src/content/winuser/nf-winuser-injecttouchinput.md
cmProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/540ac133-a371-4dbb-8f94-28d6cc77a70b
- https://authoring-docs-microsoft.poolparty.biz/devrel/caec7b7f-4941-4578-b79f-c63b1c1f5af4
- https://authoring-docs-microsoft.poolparty.biz/devrel/bcbcbad5-4208-4783-8035-8481272c98b8
spProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/60bfc045-f127-4841-9d00-ea35495a5800
- https://authoring-docs-microsoft.poolparty.biz/devrel/754dea88-f800-4835-b6b5-280cb5d81e88
- https://authoring-docs-microsoft.poolparty.biz/devrel/43b2e5aa-8a6d-4de2-a252-692232e5edc8
platformId: abb4cae8-7d21-2b75-fdca-220f1b835e78
---

# InjectTouchInput function (winuser.h) - Win32 apps | Microsoft Learn

Simulates touch input.
**Note**[InitializeTouchInjection](/en-us/windows/desktop/api/winuser/nf-winuser-initializetouchinjection) must precede any call to [InjectTouchInput](/en-us/windows/desktop/api/winuser/nf-winuser-injecttouchinput).
## Syntax

```cpp
BOOL InjectTouchInput(
  [in] UINT32                   count,
  [in] const POINTER_TOUCH_INFO *contacts
);
```

## Parameters

`[in] count`

The size of the array in *contacts*.

The maximum value for *count* is specified by the *maxCount* parameter of the [InitializeTouchInjection](/en-us/windows/desktop/api/winuser/nf-winuser-initializetouchinjection) function.

`[in] contacts`

Array of [POINTER_TOUCH_INFO](/en-us/windows/desktop/api/winuser/ns-winuser-pointer_touch_info) structures that represents all contacts on the desktop. The screen coordinates of each contact must be within the bounds of the desktop.

## Return value

If the function succeeds, the return value is non-zero.

If the function fails, the return value is zero. To get extended error information, call [GetLastError](/en-us/windows/desktop/api/errhandlingapi/nf-errhandlingapi-getlasterror).

## Remarks

The injected input is sent to the desktop of the session where the injection process is running.

There are two input states for touch input injection (interactive and hover) that are indicated by the following combinations of **pointerFlags** in *contacts*:

| **pointerFlags (POINTER\_FLAG\_\*)** | Status |
| --- | --- |
| INRANGE | UPDATE | Touch hover starts or moves |
| INRANGE | INCONTACT | DOWN | Touch contact down |
| INRANGE | INCONTACT | UPDATE | Touch contact moves |
| INRANGE | UP | Touch contact up and transition to hover |
| UPDATE | Touch hover ends |
| UP | Touch ends |

**Note** Interactive state represents a touch contact that is on-screen and able to interact with any touch-capable app. Hover state represents touch input that is not in contact with the screen and cannot interact with applications. Touch injection can start in hover or interactive state, but the state can only transition through INRANGE | INCONTACT | DOWN for hover to interactive state, or through INRANGE | UP for interactive to hover state. All touch injection sequences end with either UPDATE or UP. 
The following diagram demonstrates a touch injection sequence that starts with a hover state, transitions to interactive, and concludes with hover.

![Diagram of a touch injection sequence showing the state transitions from hover to interactive to hover.](images/inputstates.png)

For press and hold gestures, multiple frames must be sent to ensure input is not cancelled. For a press and hold at point (x,y), send [WM_POINTERDOWN](/en-us/windows/win32/inputmsg/wm-pointerdown) at point (x,y) followed by [WM_POINTERUPDATE](/en-us/windows/win32/inputmsg/wm-pointerupdate) messages at point(x,y).

Listen for [WM_DISPLAYCHANGE](/en-us/windows/desktop/gdi/wm-displaychange) to handle changes to display resolution and orientation and manage screen coordinate updates. All active contacts are cancelled when a **WM\_DISPLAYCHANGE** is received.

Cancel individual contacts by setting POINTER\_FLAG\_CANCELED with POINTER\_FLAG\_UP or POINTER\_FLAG\_UPDATE. Cancelling touch injection without POINTER\_FLAG\_UP or POINTER\_FLAG\_UPDATE invalidates the injection.

When POINTER\_FLAG\_UP is set, ptPixelLocation of [POINTER_INFO](/en-us/windows/desktop/api/winuser/ns-winuser-pointer_info) should be the same as the value of the previous touch injection frame with POINTER\_FLAG\_UPDATE. Otherwise, the injection fails with ERROR\_INVALID\_PARAMETER and all active injection contacts are cancelled. The system modifies the ptPixelLocation of the [WM_POINTERUP](/en-us/windows/win32/inputmsg/wm-pointerup) event as it cancels the injection.

The input timestamp can be specified in either the dwTime or PerformanceCount field of [POINTER_INFO](/en-us/windows/desktop/api/winuser/ns-winuser-pointer_info). The value cannot be more recent than the current tick count or [QueryPerformanceCounter](/en-us/windows/desktop/api/profileapi/nf-profileapi-queryperformancecounter) value of the injection thread. Once a frame is injected with a timestamp, all subsequent frames must include a timestamp until all contacts in the frame go to the UP state. The custom timestamp value must be provided for the first element in the contacts array. The timestamp values after the first element are ignored. The custom timestamp value must increment in every injection frame.

When a PerformanceCount field is specified, the timestamp is converted into current time in .1 millisecond resolution upon actual injection. If a custom PerformanceCount resulted in the same .1 millisecond window from previous injection, the API will return an error (ERROR\_NOT\_READY) and will not inject the data. While injection is not immediately invalidated by the error, next successful injection must have PerformanceCount value that is at least 0.1 milliseconds apart from the previously successful injection. Similarly a custom dwTime value must be at least 1 millisecond apart if the field was used.

If both dwTime and PerformanceCount are specified in the injection parameter, [InjectTouchInput](/en-us/windows/desktop/api/winuser/nf-winuser-injecttouchinput) fails with an Error Code (ERROR\_INVALID\_PARAMETER). Once the injection application starts with either a dwTime or PerformanceCount parameter, the timestamp field must be filled correctly. Injection cannot switch the custom timestamp field from one to another once the injection sequence has started.

When neither dwTime or PerformanceCount values are specified, the [InjectTouchInput](/en-us/windows/desktop/api/winuser/nf-winuser-injecttouchinput) allocates the timestamp based on the timing of the API call. If the calls are less than 0.1 millisecond apart, the API may return an error (ERROR\_NOT\_READY). The error will not invalidate the input immediately, but the injection application needs to retry the same frame again to ensure injection is successful.

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