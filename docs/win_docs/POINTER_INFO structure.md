---
layout: Conceptual
title: POINTER_INFO (winuser.h) - Win32 apps | Microsoft Learn
canonicalUrl: https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-pointer_info
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
UID: NS:winuser.tagPOINTER_INFO
description: Contains basic pointer information common to all pointer types. Applications can retrieve this information using the GetPointerInfo, GetPointerFrameInfo, GetPointerInfoHistory and GetPointerFrameInfoHistory functions.
old-location: inputmsg\pointer_info_struct.htm
tech.root: InputMsg
ms.assetid: fee176ba-ad07-4145-0b4d-1b8c335fd102
ms.date: 2018-12-05T00:00:00.0000000Z
ms.keywords: POINTER_INFO, POINTER_INFO structure [Input Messages and Notifications], _POINTER_INFO, inputmsg.pointer_info_struct, winuser/POINTER_INFO
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
req.typenames: POINTER_INFO
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
- POINTER_INFO
locale: en-us
document_id: 0af1c737-7442-d6cd-8cf0-a0a0028efcd6
document_version_independent_id: 98e47955-7e0e-6311-c17d-73b66b2e0c8b
updated_at: 2024-02-22T19:54:00.0000000Z
original_content_git_url: https://cpubwin.visualstudio.com/DefaultCollection/win32/_git/sdk-api-build?path=/sdk-api-src/content/winuser/ns-winuser-pointer_info.md&version=GBlive&_a=contents
gitcommit: https://cpubwin.visualstudio.com/DefaultCollection/win32/_git/sdk-api-build/commit/9267262487657894a8af112d7165006fed5035a7?path=/sdk-api-src/content/winuser/ns-winuser-pointer_info.md&_a=contents
git_commit_id: 9267262487657894a8af112d7165006fed5035a7
site_name: Docs
depot_name: MSDN.sdk-api-build
page_type: conceptual
toc_rel: ../_inputmsg/toc.json
pdf_url_template: https://learn.microsoft.com/pdfstore/en-us/MSDN.sdk-api-build/{branchName}{pdfName}
search.mshattr.devlang: c++
word_count: 998
asset_id: winuser/ns-winuser-pointer_info
moniker_range_name: 
monikers: []
item_type: Content
source_path: sdk-api-src/content/winuser/ns-winuser-pointer_info.md
cmProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/bcbcbad5-4208-4783-8035-8481272c98b8
- https://authoring-docs-microsoft.poolparty.biz/devrel/caec7b7f-4941-4578-b79f-c63b1c1f5af4
- https://authoring-docs-microsoft.poolparty.biz/devrel/540ac133-a371-4dbb-8f94-28d6cc77a70b
spProducts:
- https://authoring-docs-microsoft.poolparty.biz/devrel/43b2e5aa-8a6d-4de2-a252-692232e5edc8
- https://authoring-docs-microsoft.poolparty.biz/devrel/754dea88-f800-4835-b6b5-280cb5d81e88
- https://authoring-docs-microsoft.poolparty.biz/devrel/60bfc045-f127-4841-9d00-ea35495a5800
platformId: efd712ff-5d1a-ca63-45b2-20deea372445
---

# POINTER_INFO (winuser.h) - Win32 apps | Microsoft Learn

Contains basic pointer information common to all pointer types. Applications can retrieve this information using the [GetPointerInfo](/en-us/windows/desktop/api/winuser/nf-winuser-getpointerinfo), [GetPointerFrameInfo](/en-us/windows/desktop/api/winuser/nf-winuser-getpointerframeinfo), [GetPointerInfoHistory](/en-us/windows/desktop/api/winuser/nf-winuser-getpointerinfohistory) and [GetPointerFrameInfoHistory](/en-us/windows/desktop/api/winuser/nf-winuser-getpointerframeinfohistory) functions.

## Syntax

```cpp
typedef struct tagPOINTER_INFO {
  POINTER_INPUT_TYPE         pointerType;
  UINT32                     pointerId;
  UINT32                     frameId;
  POINTER_FLAGS              pointerFlags;
  HANDLE                     sourceDevice;
  HWND                       hwndTarget;
  POINT                      ptPixelLocation;
  POINT                      ptHimetricLocation;
  POINT                      ptPixelLocationRaw;
  POINT                      ptHimetricLocationRaw;
  DWORD                      dwTime;
  UINT32                     historyCount;
  INT32                      InputData;
  DWORD                      dwKeyStates;
  UINT64                     PerformanceCount;
  POINTER_BUTTON_CHANGE_TYPE ButtonChangeType;
} POINTER_INFO;
```

## Members

`pointerType`

Type: **[POINTER_INPUT_TYPE](/en-us/windows/win32/api/winuser/ne-winuser-tagpointer_input_type)**

A value from the [POINTER_INPUT_TYPE](/en-us/windows/win32/api/winuser/ne-winuser-tagpointer_input_type) enumeration that specifies the pointer type.

`pointerId`

Type: **UINT32**

An identifier that uniquely identifies a pointer during its lifetime. A pointer comes into existence when it is first detected and ends its existence when it goes out of detection range. Note that if a physical entity (finger or pen) goes out of detection range and then returns to be detected again, it is treated as a new pointer and may be assigned a new pointer identifier.

`frameId`

Type: **UINT32**

An identifier common to multiple pointers for which the source device reported an update in a single input frame. For example, a parallel-mode multi-touch digitizer may report the positions of multiple touch contacts in a single update to the system.

Note that frame identifier is assigned as input is reported to the system for all pointers across all devices. Therefore, this field may not contain strictly sequential values in a single series of messages that a window receives. However, this field will contain the same numerical value for all input updates that were reported in the same input frame by a single device.

`pointerFlags`

Type: **[POINTER_FLAGS](/en-us/windows/win32/inputmsg/pointer-flags-contants)**

May be any reasonable combination of flags from the [Pointer Flags](/en-us/windows/win32/inputmsg/pointer-flags-contants) constants.

`sourceDevice`

Type: **HANDLE**

Handle to the source device that can be used in calls to the raw input device API and the digitizer device API.

`hwndTarget`

Type: **HWND**

Window to which this message was targeted. If the pointer is captured, either implicitly by virtue of having made contact over this window or explicitly using the pointer capture API, this is the capture window. If the pointer is uncaptured, this is the window over which the pointer was when this message was generated.

`ptPixelLocation`

Type: **[POINT](/en-us/windows/win32/api/windef/ns-windef-point)**

The predicted screen coordinates of the pointer, in pixels.

The predicted value is based on the pointer position reported by the digitizer and the motion of the pointer. This correction can compensate for visual lag due to inherent delays in sensing and processing the pointer location on the digitizer. This is applicable to pointers of type [PT_TOUCH](/en-us/windows/win32/api/winuser/ne-winuser-tagpointer_input_type). For other pointer types, the predicted value will be the same as the non-predicted value (see **ptPixelLocationRaw**).

`ptHimetricLocation`

Type: **[POINT](/en-us/windows/win32/api/windef/ns-windef-point)**

The predicted screen coordinates of the pointer, in HIMETRIC units.

The predicted value is based on the pointer position reported by the digitizer and the motion of the pointer. This correction can compensate for visual lag due to inherent delays in sensing and processing the pointer location on the digitizer. This is applicable to pointers of type [PT_TOUCH](/en-us/windows/win32/api/winuser/ne-winuser-tagpointer_input_type). For other pointer types, the predicted value will be the same as the non-predicted value (see **ptHimetricLocationRaw**).

`ptPixelLocationRaw`

Type: **[POINT](/en-us/windows/win32/api/windef/ns-windef-point)**

The screen coordinates of the pointer, in pixels. For adjusted screen coordinates, see **ptPixelLocation**.

`ptHimetricLocationRaw`

Type: **[POINT](/en-us/windows/win32/api/windef/ns-windef-point)**

The screen coordinates of the pointer, in HIMETRIC units. For adjusted screen coordinates, see **ptHimetricLocation**.

`dwTime`

Type: **DWORD**

0 or the time stamp of the message, based on the system tick count when the message was received.

The application can specify the input time stamp in either **dwTime** or **PerformanceCount**. The value cannot be more recent than the current tick count or **QueryPerformanceCount (QPC)** value of the injection thread. Once a frame is injected with a time stamp, all subsequent frames must include a timestamp until all contacts in the frame go to an [UP](/en-us/windows/desktop/api/winuser/ne-winuser-pointer_button_change_type) state. The custom timestamp value must also be provided for the first element in the contacts array. The time stamp values after the first element are ignored. The custom timestamp value must increment in every injection frame.

When **PerformanceCount** is specified, the time stamp will be converted to the current time in .1 millisecond resolution upon actual injection. If a custom **PerformanceCount** resulted in the same .1 millisecond window from the previous injection, **ERROR\_NOT\_READY** is returned and injection will not occur. While injection will not be invalidated immediately by the error, the next successful injection must have a **PerformanceCount** value that is at least 0.1 millisecond from the previously successful injection. This is also true if **dwTime** is used.

If both **dwTime** and **PerformanceCount** are specified in [InjectTouchInput](/en-us/windows/desktop/api/winuser/nf-winuser-injecttouchinput), ERROR\_INVALID\_PARAMETER is returned.

[InjectTouchInput](/en-us/windows/desktop/api/winuser/nf-winuser-injecttouchinput) cannot switch between **dwTime** and **PerformanceCount** once injection has started.

If neither **dwTime** and **PerformanceCount** are specified, [InjectTouchInput](/en-us/windows/desktop/api/winuser/nf-winuser-injecttouchinput) allocates the timestamp based on the timing of the call. If **InjectTouchInput** calls are repeatedly less than 0.1 millisecond apart, ERROR\_NOT\_READY might be returned. The error will not invalidate the input immediately, but the injection application needs to retry the same frame again for injection to succeed.

`historyCount`

Type: **UINT32**

Count of inputs that were coalesced into this message. This count matches the total count of entries that can be returned by a call to [GetPointerInfoHistory](/en-us/windows/desktop/api/winuser/nf-winuser-getpointerinfohistory). If no coalescing occurred, this count is 1 for the single input represented by the message.

`InputData`

`dwKeyStates`

Type: **DWORD**

Indicates which keyboard modifier keys were pressed at the time the input was generated. May be zero, or a combination of the following values from [Modifier Key State](/en-us/windows/win32/inputmsg/modifier-key-states-constants).

POINTER\_MOD\_SHIFT – A SHIFT key was pressed.

POINTER\_MOD\_CTRL – A CTRL key was pressed.

Use [GetKeyState](/en-us/windows/desktop/api/winuser/nf-winuser-getkeystate).

`PerformanceCount`

Type: **UINT64**

The value of the high-resolution performance counter when the pointer message was received (high-precision, 64 bit alternative to **dwTime**). The value can be calibrated when the touch digitizer hardware supports the scan timestamp information in its input report.

`ButtonChangeType`

Type: **POINTER\_BUTTON\_CHANGE\_TYPE**

A value from the [POINTER_BUTTON_CHANGE_TYPE](/en-us/windows/desktop/api/winuser/ne-winuser-pointer_button_change_type) enumeration that specifies the change in button state between this input and the previous input.

## Requirements

| Requirement | Value |
| --- | --- |
| **Minimum supported client** | Windows 8 [desktop apps only] |
| **Minimum supported server** | Windows Server 2012 [desktop apps only] |
| **Header** | winuser.h (include Windows.h) |