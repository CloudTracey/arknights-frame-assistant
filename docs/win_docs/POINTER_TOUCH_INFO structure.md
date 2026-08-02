---
layout: Conceptual
title: POINTER_TOUCH_INFO (winuser.h) - Win32 apps | Microsoft Learn
canonicalUrl: https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-pointer_touch_info
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
UID: NS:winuser.tagPOINTER_TOUCH_INFO
description: Defines basic touch information common to all pointer types.
old-location: inputmsg\pointer_touch_info_struct.htm
tech.root: InputMsg
ms.assetid: fee176ba-ad07-3141-ab4d-1b8c335fd102
ms.date: 2018-12-05T00:00:00.0000000Z
ms.keywords: POINTER_TOUCH_INFO, POINTER_TOUCH_INFO structure [Input Messages and Notifications], _POINTER_TOUCH_INFO, inputmsg.pointer_touch_info_struct, winuser/POINTER_TOUCH_INFO
req.header: winuser.h
req.include-header: Windows.h
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
req.lib: 
req.dll: 
req.irql: 
targetos: Windows
req.typenames: POINTER_TOUCH_INFO
req.redist: 
ms.custom: 19H1
topic_type:
- APIRef
- kbSyntax
api_type:
- HeaderDef
api_location:
- Winuser.h
api_name:
- POINTER_TOUCH_INFO
locale: en-us
document_id: 1d401a41-9b80-254b-f42b-afd1c241c1f9
document_version_independent_id: 3ae812ef-59c3-42de-5a53-7d2b22823d19
updated_at: 2024-02-22T19:54:00.0000000Z
original_content_git_url: https://cpubwin.visualstudio.com/DefaultCollection/win32/_git/sdk-api-build?path=/sdk-api-src/content/winuser/ns-winuser-pointer_touch_info.md&version=GBlive&_a=contents
gitcommit: https://cpubwin.visualstudio.com/DefaultCollection/win32/_git/sdk-api-build/commit/9267262487657894a8af112d7165006fed5035a7?path=/sdk-api-src/content/winuser/ns-winuser-pointer_touch_info.md&_a=contents
git_commit_id: 9267262487657894a8af112d7165006fed5035a7
site_name: Docs
depot_name: MSDN.sdk-api-build
page_type: conceptual
toc_rel: ../_inputmsg/toc.json
pdf_url_template: https://learn.microsoft.com/pdfstore/en-us/MSDN.sdk-api-build/{branchName}{pdfName}
search.mshattr.devlang: c++
word_count: 293
asset_id: winuser/ns-winuser-pointer_touch_info
moniker_range_name: 
monikers: []
item_type: Content
source_path: sdk-api-src/content/winuser/ns-winuser-pointer_touch_info.md
cmProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/caec7b7f-4941-4578-b79f-c63b1c1f5af4
- https://authoring-docs-microsoft.poolparty.biz/devrel/bcbcbad5-4208-4783-8035-8481272c98b8
spProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/754dea88-f800-4835-b6b5-280cb5d81e88
- https://authoring-docs-microsoft.poolparty.biz/devrel/43b2e5aa-8a6d-4de2-a252-692232e5edc8
platformId: 4dd37d00-a01c-b4b6-3a0f-99b168889774
---

# POINTER_TOUCH_INFO (winuser.h) - Win32 apps | Microsoft Learn

Defines basic touch information common to all pointer types.

## Syntax

```cpp
typedef struct tagPOINTER_TOUCH_INFO {
  POINTER_INFO pointerInfo;
  TOUCH_FLAGS  touchFlags;
  TOUCH_MASK   touchMask;
  RECT         rcContact;
  RECT         rcContactRaw;
  UINT32       orientation;
  UINT32       pressure;
} POINTER_TOUCH_INFO;
```

## Members

`pointerInfo`

Type: **[POINTER_INFO](ns-winuser-pointer_info)**

An embedded [POINTER_INFO](ns-winuser-pointer_info) header structure.

`touchFlags`

Type: **[Touch Flags](/en-us/windows/win32/inputmsg/touch-flags-constants)**

Currently none.

`touchMask`

Type: **[Touch Mask](/en-us/windows/win32/inputmsg/touch-mask-constants)**

Indicates which of the optional fields contain valid values. The member can be zero or any combination of the values from the [Touch Mask](/en-us/windows/win32/inputmsg/touch-mask-constants) constants.

`rcContact`

Type: **RECT**

The predicted screen coordinates of the contact area, in pixels. By default, if the device does not report a contact area, this field defaults to a 0-by-0 rectangle centered around the pointer location.

The predicted value is based on the pointer position reported by the digitizer and the motion of the pointer. This correction can compensate for visual lag due to inherent delays in sensing and processing the pointer location on the digitizer. This is applicable to pointers of type [PT_TOUCH](ne-winuser-tagpointer_input_type).

`rcContactRaw`

Type: **RECT**

The raw screen coordinates of the contact area, in pixels. For adjusted screen coordinates, see **rcContact**.

`orientation`

Type: **UINT32**

A pointer orientation, with a value between 0 and 359, where 0 indicates a touch pointer aligned with the x-axis and pointing from left to right; increasing values indicate degrees of rotation in the clockwise direction.

This field defaults to 0 if the device does not report orientation.

Note

Some touchscreen devices that support orientation will only report half-range (0-180°) values, while other devices will only report full-range (0-359°) values.

`pressure`

Type: **UINT32**

A pen pressure normalized to a range between 0 and 1024. The default is 512.

## Requirements

| Requirement | Value |
| --- | --- |
| **Minimum supported client** | Windows 8 [desktop apps only] |
| **Minimum supported server** | Windows Server 2012 [desktop apps only] |
| **Header** | winuser.h (include Windows.h) |